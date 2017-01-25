module Haconiwa
  class Runner
  end

  class LinuxRunner < Runner
    def initialize(base)
      @base = base
      if Haconiwa.config.etcd_available?
        @etcd = Etcd::Client.new(Haconiwa.config.etcd_url)
        base.etcd_name = @etcd.stats["name"]
      end
    end

    def run(init_command)
      if File.exist? @base.container_pid_file
        Logger.err "PID file #{@base.container_pid_file} exists. You may be creating the container with existing name #{@base.name}!"
      end
      unless init_command.empty?
        @base.init_command = init_command
      end

      wrap_daemonize do |base, notifier|
        jail_pid(base)
        # The pipe to set guid maps
        if base.namespace.use_guid_mapping?
          r,  w  = IO.pipe
          r2, w2 = IO.pipe
        end
        done, kick_ok = IO.pipe

        pid = Process.fork do
          ::Procutil.mark_cloexec
          [r, w2].each {|io| io.close if io }
          done.close
          ::Procutil.setsid if base.daemon?

          apply_namespace(base.namespace)
          apply_filesystem(base)
          apply_rlimit(base.resource)
          apply_cgroup(base)
          apply_remount(base)
          ::Procutil.sethostname(base.name)

          apply_user_namespace(base.namespace)
          if base.namespace.use_guid_mapping?
            # ping and pong between parent
            w.puts "unshared"
            w.close

            r2.read
            r2.close
            switch_current_namespace_root
          end

          do_chroot(base)
          reopen_fds(base.command) if base.daemon?

          apply_capability(base.capabilities)
          switch_guid(base.guid)
          kick_ok.puts "done"
          kick_ok.close

          Logger.info "Container is going to exec: #{base.init_command.inspect}"
          Exec.execve(base.environ, *base.init_command)
        end
        base.pid = pid
        kick_ok.close

        File.open(base.container_pid_file, 'w') {|f| f.write pid }
        if base.namespace.use_guid_mapping?
          Logger.info "Using gid/uid mapping in this container..."
          [w, r2].each {|io| io.close }
          r.read
          r.close
          set_guid_mapping(base.namespace, pid)
          Logger.info "Mapping setup is OK"

          w2.puts "mapped"
          w2.close
        end

        done.read # wait for container is done
        done.close
        persist_namespace(pid, base.namespace)

        if notifier
          notifier.puts pid.to_s
          notifier.close # notify container is up
        end

        Logger.puts "Container fork success and going to wait: pid=#{pid}"
        base.waitloop.register_hooks(base)
        base.waitloop.register_sighandlers(base, self, @etcd)
        base.waitloop.register_custom_sighandlers(base, base.signal_handler)

        pid, status = base.waitloop.run_and_wait(pid)
        cleanup_supervisor(base, @etcd)
        if status.success?
          Logger.puts "Container successfully exited: #{status.inspect}"
        else
          Logger.warning "Container failed: #{status.inspect}"
        end
      end
    end

    def attach(exe)
      base = @base
      if !base.pid
        if File.exist? base.container_pid_file
          base.pid = File.read(base.container_pid_file).to_i
        else
          Logger.err "PID file #{base.container_pid_file} doesn't exist. You may be specifying container PID by -t option"
        end
      end

      if exe.empty?
        exe = "/bin/bash"
      end

      if base.namespace.use_pid_ns
        ::Namespace.setns(::Namespace::CLONE_NEWPID, pid: base.pid)
      end
      pid = Process.fork do
        flag = base.namespace.to_flag & (~(::Namespace::CLONE_NEWPID))
        ::Namespace.setns(flag, pid: base.pid)

        apply_cgroup(base)
        do_chroot(base)

        switch_current_namespace_root if base.namespace.use_guid_mapping?
        apply_capability(base.attached_capabilities)
        switch_guid(base.guid)

        Logger.info "Attach process is going to exec: #{base.init_command.inspect}"
        Exec.exec(*exe)
      end
      Logger.info "Attach process fork success: pid=#{pid}"

      pid, status = Process.waitpid2 pid
      if status.success?
        Logger.puts "Process successfully exited: #{status.inspect}"
      else
        Logger.warning "Process failed: #{status.inspect}"
      end
    end

    def kill(sigtype)
      if !@base.pid
        if File.exist? @base.container_pid_file
          @base.pid = File.read(@base.container_pid_file).to_i
        else
          raise "PID file #{@base.container_pid_file} doesn't exist. You may be specifying container PID by -t option - or the container is already killed."
        end
      end

      case sigtype.to_s
      when "INT"
        Process.kill :INT, @base.pid
      when "TERM"
        Process.kill :TERM, @base.pid
      when "KILL"
        Process.kill :KILL, @base.pid
      else
        raise "Invalid or unsupported signal type: #{sigtype}"
      end

      10.times do
        sleep 0.1
        unless File.exist?(@base.container_pid_file)
          Logger.puts "Kill success"
          Process.exit 0
        end
      end

      Logger.warning "Killing seemd to be failed in 1 second"
      Process.exit 1
    end

    def cleanup_supervisor(base, etcd=nil)
      cleanup_cgroup(base)
      if etcd
        etcd.delete base.etcd_key
      end
      File.unlink base.container_pid_file
      base.cleaned = true
    end

    private

    def wrap_daemonize(&b)
      if @base.daemon?
        Logger.info "Container is running in daemon mode"
        r, w = IO.pipe
        ppid = Process.fork do
          # TODO: logging
          r.close
          ::Procutil.daemon_fd_reopen
          b.call(@base, w)
        end
        w.close
        pid = r.read
        r.close

        @base.created_at = Time.now
        @base.pid = pid.to_i
        @base.supervisor_pid = ppid
        if @etcd
          @etcd.put @base.etcd_key, @base.to_container_json
        end

        Logger.puts "Container successfully up. PID={container: #{@base.pid}, supervisor: #{@base.supervisor_pid}}"
      else
        b.call(@base, nil)
      end
    end

    def jail_pid(base)
      ret = if base.namespace.use_pid_ns
              ::Namespace.unshare(::Namespace::CLONE_NEWPID)
            elsif base.namespace.enter_existing_pidns?
              f = File.open(namespace.ns_to_path[::Namespace::CLONE_NEWPID])
              r = ::Namespace.setns(ns, fd: f.fileno)
              f.close
              r
            else
              0
            end
      if ret < 0
        Logger.err "Unsharing or setting PID namespace failed"
      end
    end

    def apply_namespace(namespace)
      if ::Namespace.unshare(namespace.to_flag_for_unshare) < 0
        Logger.err "Some namespace is unsupported by this kernel. Please check"
      end

      if namespace.setns_on_run?
        namespace.ns_to_path.each do |ns, path|
          next if ns == ::Namespace::CLONE_NEWPID
          next if ns == ::Namespace::CLONE_NEWUSER
          f = File.open(path)
          if ::Namespace.setns(ns, fd: f.fileno) < 0
            Logger.err "Some namespace is unsupported by this kernel. Please check"
          end
          f.close
        end
      end
    end

    def apply_user_namespace(namespace)
      flg = namespace.to_flag & ::Namespace::CLONE_NEWUSER
      if flg != 0 and ::Namespace.unshare(flg) < 0
        raise "User namespace is unsupported by this kernel. Please check"
      end

      if path = namespace.ns_to_path[::Namespace::CLONE_NEWUSER]
        f = File.open(path)
        if ::Namespace.setns(::Namespace::CLONE_NEWUSER, fd: f.fileno) < 0
          raise "User namespace is unsupported by this kernel. Please check"
        end
        f.close
      end
    end

    def set_guid_mapping(namespace, pid)
      if m = namespace.uid_mapping
        File.open("/proc/#{pid}/uid_map", "w") do |map|
          map.write "#{m[:min].to_i} #{m[:offset].to_i} #{m[:max].to_i}"
        end
      end

      if m = namespace.gid_mapping
        File.open("/proc/#{pid}/gid_map", "w") do |map|
          map.write "#{m[:min].to_i} #{m[:offset].to_i} #{m[:max].to_i}"
        end
      end
    end

    def apply_filesystem(base)
      cwd = Dir.pwd
      m = Mount.new
      m.make_private "/"
      owner_options = base.rootfs.to_owner_options
      base.filesystem.mount_points.each do |mp|
        case
        when mp.fs
          m.mount mp.normalized_src(cwd), mp.dest, owner_options.merge(mp.options).merge(type: mp.fs)
        else
          m.bind_mount mp.normalized_src(cwd), mp.dest, owner_options.merge(mp.options)
        end
      end
      base.network_mountpoint.each do |mp|
        unless File.exist? mp.dest
          File.open(mp.dest, "w+") {|f| f.print "" }
        end
        m.bind_mount mp.normalized_src(cwd), mp.dest, {readonly: true}.merge(owner_options)
      end
    end

    CG_MAPPING = {
      "cpu"     => Cgroup::CPU,
      "cpuset"  => Cgroup::CPUSET,
      "cpuacct" => Cgroup::CPUACCT,
      "blkio"   => Cgroup::BLKIO,
      "memory"  => Cgroup::MEMORY,
      "pids"    => Cgroup::PIDS,
    }
    def apply_cgroup(base)
      base.cgroup.controllers.each do |controller|
        Logger.debug "Creating cgroup controller #{controller}"
        Logger.err("Invalid or unsupported controller name: #{controller}") unless CG_MAPPING.has_key?(controller)

        c = CG_MAPPING[controller].new(base.name)
        base.cgroup.groups_by_controller[controller].each do |pair|
          key, attr = pair
          value = base.cgroup[key]
          c.send "#{attr}=", value
        end
        c.create
        c.attach
      end

      unless base.cgroupv2.groups.empty?
        cg = ::CgroupV2.new_group(base.name)
        cg.create
        base.cgroupv2.groups.each do |key, value|
          cg[key.to_s] = value.to_s
        end
        cg.commit
        cg.attach
      end
    end

    def cleanup_cgroup(base)
      base.cgroup.controllers.each do |controller|
        Logger.err("Invalid or unsupported controller name: #{controller}") unless CG_MAPPING.has_key?(controller)

        c = CG_MAPPING[controller].new(base.name)
        c.delete
      end
    end

    # TODO: check inheritable
    #       and handling when it is non-root
    def apply_capability(capabilities)
      if capabilities.acts_as_whitelist?
        ids = capabilities.whitelist_ids
        (0..38).each do |cap|
          break unless ::Capability.supported? cap
          next if ids.include?(cap)
          Logger.debug "Dropping cap of #{cap}"
          ::Capability.drop_bound cap
        end
      else
        capabilities.blacklist_ids.each do |cap|
          Logger.debug "Dropping cap of #{cap}"
          ::Capability.drop_bound cap
        end
      end
    rescue => e
      showid = capabilities.acts_as_whitelist? ? capabilities.whitelist_ids : capabilities.blacklist_ids
      Logger.err "Maybe there are unsupported caps in #{showid.inspect}: #{e.class} - #{e.message}"
    end

    def apply_rlimit(rlimit)
      rlimit.limits.each do |limit|
        type = ::Resource.const_get("RLIMIT_#{limit[0]}")
        value = [:unlimited, :infinity].include?(limit[1]) ? ::Resource::RLIM_INFINITY : limit[1]
        ::Resource.setrlimit(type, value)
      end
    end

    def apply_remount(base)
      m = Mount.new
      owner_options = base.rootfs.to_owner_options
      base.filesystem.independent_mount_points.each do |mp|
        opts = ["tmpfs", "devpts"].include?(mp.fs) ? {type: mp.fs}.merge(owner_options) : {type: mp.fs}
        m.mount mp.src, "#{base.filesystem.chroot}#{mp.dest}",opts
      end
    end

    def reopen_fds(command)
      devnull = "/dev/null"
      inio  = command.stdin  || File.open(devnull, 'r')
      outio = command.stdout || File.open(devnull, 'a')
      errio = command.stderr || File.open(devnull, 'a')
      ::Procutil.fd_reopen3(inio.fileno, outio.fileno, errio.fileno)
    end

    def do_chroot(base)
      Dir.chdir File.expand_path([base.filesystem.chroot, base.workdir].join('/'))
      Dir.chroot base.filesystem.chroot
    end

    def switch_current_namespace_root
      ::Process::Sys.setgid(0)
      ::Process::Sys.setuid(0)
    end

    def switch_guid(guid)
      if guid.gid
        ::Process::Sys.setgid(guid.gid)
        ::Process::Sys.__setgroups(guid.groups + [guid.gid])
      else
        # Assume gid is same as uid
        ::Process::Sys.setgid(guid.uid) if guid.uid
      end
      ::Process::Sys.setuid(guid.uid) if guid.uid
    end

    def persist_namespace(pid, namespace)
      namespace.namespaces.each do |flag, options|
        if path = options[:persist_in]
          ::Namespace.persist_ns pid, flag, path
          Logger.info "Namespace is persisted: #{path}"
        end
      end
    end
  end
end
