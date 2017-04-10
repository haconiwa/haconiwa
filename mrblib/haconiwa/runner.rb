module Haconiwa
  class Runner
  end

  class LinuxRunner < Runner
    def initialize(base)
      @base = base
    end

    VALID_HOOKS = [
      :before_fork,
      :after_fork,
      :before_chroot,
      :after_chroot,
      :before_start_wait,
      :teardown,
      :after_reload,
    ]

    def waitall(&how_you_run)
      wrap_daemonize do |base, n|
        pids = how_you_run.call(n)

        if n
          n.print pids.join(',')
          n.close
        end

        while res = ::Process.waitpid2(-1)
          pid, status = res[0], res[1]
          pids.delete(pid)
          Logger.puts "A container finished: #{pid}, #{status.inspect}"
          break if pids.empty?
        end
      end
    end

    def run(options, init_command)
      begin
        confirm_existence_pid_file(@base.container_pid_file)
      rescue => e
        Logger.exception e
      end

      unless init_command.empty?
        @base.init_command = init_command
      end

      raise_container do |base|
        invoke_general_hook(:before_fork, base)

        init_pidns_fd = nil
        begin
          init_pidns_fd = File.open("/proc/1/ns/pid", 'r')
        rescue => e
          Logger.warning "Failed to open original PID namespace file. This restricts some features of Haconiwa"
        end if base.namespace.flag?(::Namespace::CLONE_NEWPID)

        jail_pid(base)
        # The pipe to set guid maps
        if base.namespace.use_guid_mapping?
          r,  w  = IO.pipe
          r2, w2 = IO.pipe
        end
        done, kick_ok = IO.pipe
        pid = Process.fork do
          invoke_general_hook(:after_fork, base)

          begin
            ::Procutil.mark_cloexec
            [r, w2].each {|io| io.close if io }
            done.close
            ::Procutil.setsid if base.daemon?

            apply_namespace(base.namespace)
            apply_filesystem(base)
            apply_rlimit(base.resource)
            apply_cgroup(base)
            apply_remount(base)
            ::Procutil.sethostname(base.name) if base.namespace.flag?(::Namespace::CLONE_NEWUTS)

            apply_user_namespace(base.namespace)
            if base.namespace.use_guid_mapping?
              # ping and pong between parent
              w.puts "unshared"
              w.close

              r2.read
              r2.close
              switch_current_namespace_root
            end

            invoke_general_hook(:before_chroot, base)

            do_chroot(base)
            invoke_general_hook(:after_chroot, base)

            reopen_fds(base.command) if base.daemon?

            apply_capability(base.capabilities)
            switch_guid(base.guid)
            kick_ok.puts "done"
            kick_ok.close

            Logger.info "Container is going to exec: #{base.init_command.inspect}"
            Exec.execve(base.environ, *base.init_command)
          rescue => e
            Logger.exception(e)
            exit(127)
          end
        end
        ::Namespace.setns(::Namespace::CLONE_NEWPID, fd: init_pidns_fd.fileno) if init_pidns_fd
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

        base.created_at = Time.now
        base.pid = pid.to_i
        base.supervisor_pid = ::Process.pid

        Logger.puts "Container fork success and going to wait: pid=#{pid}"
        base.waitloop.register_hooks(base)
        base.waitloop.register_sighandlers(base, self)
        base.waitloop.register_custom_sighandlers(base, base.signal_handler)

        invoke_general_hook(:before_start_wait, base)
        Logger.debug "WaitLoop instance status: #{base.waitloop.inspect}"

        pid, status = base.waitloop.run_and_wait(pid)
        base.exit_status = status
        invoke_general_hook(:teardown, base)

        cleanup_supervisor(base)
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
          Logger.exception "PID file #{base.container_pid_file} doesn't exist. You may be specifying container PID by -t option"
        end
      end

      if exe.empty?
        exe = "/bin/bash"
      end

      if base.namespace.use_pid_ns
        ::Namespace.setns(::Namespace::CLONE_NEWPID, pid: base.pid)
      end
      pid = Process.fork do
        flag = base.namespace.to_flag_without_pid_and_user
        ::Namespace.setns(flag, pid: base.pid)

        if base.namespace.to_flag & ::Namespace::CLONE_NEWUSER != 0
          ::Namespace.setns(::Namespace::CLONE_NEWUSER, pid: base.pid)
        end

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

    def reload(name, new_cg, new_cg2, targets)
      if targets.include?(:cgroup)
        Haconiwa::Logger.info "Reloading... :cgroup"
        reapply_cgroup(name, new_cg, new_cg2)
      end

      invoke_general_hook(:after_reload, @base)
    end

    def kill(sigtype, timeout)
      if !@base.pid
        if File.exist? @base.container_pid_file
          @base.pid = File.read(@base.container_pid_file).to_i
        else
          raise "PID file #{@base.container_pid_file} doesn't exist. You may be specifying container PID by -t option - or the container is already killed."
        end
      end

      ::Process.kill sigtype.to_sym, @base.pid

      # timeout < 0 means "do not wait"
      if timeout < 0
        Logger.puts "Send signal success"
        return
      end

      (timeout * 10).times do
        usleep 1000
        unless File.exist?(@base.container_pid_file)
          Logger.puts "Kill success"
          return
        end
      end

      Logger.warning "Killing seemd to be failed in #{timeout} seconds. Check out process PID=#{@base.pid}"
      Process.exit 1
    end

    def cleanup_supervisor(base)
      cleanup_cgroup(base)
      File.unlink base.container_pid_file
      base.cleaned = true
    end

    private

    def raise_container(&b)
      b.call(@base)
    end

    def wrap_daemonize(&b)
      if @base.daemon?
        r, w = IO.pipe
        ppid = Process.fork do
          begin
            # TODO: logging
            r.close
            ::Procutil.daemon_fd_reopen
            b.call(@base, w)
          rescue => e
            Logger.exception(e)
          ensure
            File.unlink @base.supervisor_all_pid_file
          end
        end
        w.close
        File.open(@base.supervisor_all_pid_file, 'w') {|f| f.write ppid }
        _pids = r.read
        Logger.puts "pids: #{_pids}"
        pids = _pids.split(',').map{|v| v.to_i }
        r.close

        Logger.puts "Container cluster successfully up. PID={supervisors: #{pids.inspect}, root: #{ppid}}"
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
        Logger.exception "Unsharing or setting PID namespace failed"
      end
    end

    def invoke_general_hook(hookpoint, base)
      hook = base.general_hooks[hookpoint]
      hook.call(base) if hook
    rescue Exception => e
      Logger.warning("General container hook at #{hookpoint.inspect} failed. Skip")
      Logger.warning("#{e.class} - #{e.message}")
    end

    def apply_namespace(namespace)
      if ::Namespace.unshare(namespace.to_flag_for_unshare) < 0
        Logger.exception "Some namespace is unsupported by this kernel. Please check"
      end

      if namespace.setns_on_run?
        namespace.ns_to_path.each do |ns, path|
          next if ns == ::Namespace::CLONE_NEWPID
          next if ns == ::Namespace::CLONE_NEWUSER
          f = File.open(path)
          if ::Namespace.setns(ns, fd: f.fileno) < 0
            Logger.exception "Some namespace is unsupported by this kernel. Please check"
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
        Logger.exception("Invalid or unsupported controller name: #{controller}") unless CG_MAPPING.has_key?(controller)

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

    def reapply_cgroup(name, cgroup, cgroupv2)
      if cgroup
        cgroup.controllers.each do |controller|
          Logger.debug "Modifying cgroup controller #{controller}"
          Logger.exception("Invalid or unsupported controller name: #{controller}") unless CG_MAPPING.has_key?(controller)
          cls = CG_MAPPING[controller]
          c = cls.new(name)
          cgroup.groups_by_controller[controller].each do |pair|
            key, attr = pair
            value = cgroup[key]
            c.send "#{attr}=", value
          end
          c.modify
        end
      end

      if cgroupv2 && !cgroupv2.groups.empty?
        cg = ::CgroupV2.new_group(name)
        cgroupv2.groups.each do |key, value|
          cg[key.to_s] = value.to_s
        end
        cg.commit
      end
    rescue Exception => e
      Haconiwa::Logger.warning "Reapply failed: #{e.class}, #{e.message}"
      e.backtrace.each{|l| Haconiwa::Logger.warning "    #{l}" }
    end

    def cleanup_cgroup(base)
      base.cgroup.controllers.each do |controller|
        Logger.exception("Invalid or unsupported controller name: #{controller}") unless CG_MAPPING.has_key?(controller)

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
      Logger.exception "Maybe there are unsupported caps in #{showid.inspect}: #{e.class} - #{e.message}"
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
      if base.filesystem.chroot
        Dir.chdir File.expand_path([base.filesystem.chroot, base.workdir].join('/'))
        Dir.chroot base.filesystem.chroot
      else
        Dir.chdir base.workdir
      end
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

    def process_exists?(pid)
      ::Process.kill(0, pid)
    rescue RuntimeError
      false
    end

    def confirm_existence_pid_file(pid_file)
      if File.exist? pid_file
        if process_exists?(File.read(pid_file).to_i)
          raise "PID file #{pid_file} exists. You may be creating the container with existing name #{@base.name}!"
        else
          begin
            File.unlink(pid_file)
            Haconiwa::Logger.debug("Since the process does not exist, delete the PID file #{pid_file}")
          rescue
            raise "Failed to delete PID file #{pid_file}."
          end
        end
      end
    end
  end
end
