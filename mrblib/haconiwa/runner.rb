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
        raise "PID file #{@base.container_pid_file} exists. You may be creating the container with existing name #{@base.name}!"
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

        pid = Process.fork do
          p r, w, r2, w2
          [r, w2].each {|io| io.close if io }
          apply_namespace(base.namespace)
          if w
            w.puts "unshared"
            w.close
          end

          apply_filesystem(base)
          apply_rlimit(base.resource)
          apply_cgroup(base)
          apply_capability(base.capabilities)
          do_chroot(base)
          ::Procutil.sethostname(base.name)

          if base.namespace.use_guid_mapping?
            r2.read
            r2.close
          end

          switch_guid(base)
          Exec.exec(*base.init_command)
        end

        File.open(base.container_pid_file, 'w') {|f| f.write pid }
        if base.namespace.use_guid_mapping?
          [w, r2].each {|io| io.close }
          r.read
          r.close
          set_guid_mapping(base.namespace, pid)
          w2.puts "mapped"
          w2.close
        end

        base.signal_handler.register_handlers!

        if notifier
          notifier.puts pid.to_s
          notifier.close # notify container is up
        end

        runner, etcd = self, @etcd
        [:SIGTERM, :SIGINT, :SIGHUP, :SIGPIPE].each do |sig|
          Signal.trap(sig) do |signo|
            unless base.cleaned
              puts "Supervisor received unintended kill. Cleanup..."
              runner.cleanup_supervisor(base, etcd)
            end
            exit 127
          end
        end

        pid, status = Process.waitpid2 pid
        cleanup_supervisor(base, @etcd)
        if status.success?
          puts "Container successfully exited: #{status.inspect}"
        else
          puts "Container failed: #{status.inspect}"
        end
      end
    end

    def attach(exe)
      base = @base
      if !base.pid
        if File.exist? base.container_pid_file
          base.pid = File.read(base.container_pid_file).to_i
        else
          raise "PID file #{base.container_pid_file} doesn't exist. You may be specifying container PID by -t option"
        end
      end

      if exe.empty?
        exe = "/bin/bash"
      end

      if base.namespace.use_pid_ns
        ::Namespace.setns(::Namespace::CLONE_NEWPID, pid: base.pid)
      end
      pid = Process.fork do
        ::Namespace.setns(base.namespace.to_flag_without_pid, pid: base.pid)

        apply_cgroup(base)
        apply_capability(base.attached_capabilities)
        do_chroot(base, false)
        Exec.exec(*exe)
      end

      pid, status = Process.waitpid2 pid
      if status.success?
        puts "Process successfully exited: #{status.inspect}"
      else
        puts "Process failed: #{status.inspect}"
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
          puts "Kill success"
          Process.exit 0
        end
      end

      puts "Killing seemd to be failed in 1 second"
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
        r, w = IO.pipe
        ppid = Process.fork do
          # TODO: logging
          r.close
          Procutil.daemon_fd_reopen
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

        puts "Container successfully up. PID={container: #{@base.pid}, supervisor: #{@base.supervisor_pid}}"
      else
        b.call(@base, nil)
      end
    end

    def jail_pid(base)
      if base.namespace.use_pid_ns
        ::Namespace.unshare(::Namespace::CLONE_NEWPID)
      end
    end

    def apply_namespace(namespace)
      ::Namespace.unshare(namespace.to_flag_for_unshare)

      if namespace.setns_on_run?
        namespace.ns_to_path.each do |ns, path|
          f = File.open(path)
          ::Namespace.setns(ns, fd: f.fileno)
          f.close
        end
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
      m = Mount.new
      m.make_private "/"
      base.filesystem.mount_points.each do |mp|
        case
        when mp.fs
          m.mount mp.src, mp.dest, mp.options.merge(type: mp.fs)
        else
          m.bind_mount mp.src, mp.dest, mp.options
        end
      end
      base.network_mountpoint.each do |mp|
        unless File.exist? mp.dest
          File.open(mp.dest, "w+") {|f| f.print "" }
        end
        m.bind_mount mp.src, mp.dest, readonly: true
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
        raise("Invalid or unsupported controller name: #{controller}") unless CG_MAPPING.has_key?(controller)

        c = CG_MAPPING[controller].new(base.name)
        base.cgroup.groups_by_controller[controller].each do |pair|
          key, attr = pair
          value = base.cgroup[key]
          c.send "#{attr}=", value
        end
        c.create
        c.attach
      end
    end

    def cleanup_cgroup(base)
      base.cgroup.controllers.each do |controller|
        raise("Invalid or unsupported controller name: #{controller}") unless CG_MAPPING.has_key?(controller)

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
          ::Capability.drop_bound cap
        end
      else
        capabilities.blacklist_ids.each do |cap|
          ::Capability.drop_bound cap
        end
      end
    end

    def apply_rlimit(rlimit)
      rlimit.limits.each do |limit|
        type = ::Resource.const_get("RLIMIT_#{limit[0]}")
        value = [:unlimited, :infinity].include?(limit[1]) ? ::Resource::RLIM_INFINITY : limit[1]
        ::Resource.setrlimit(type, value)
      end
    end

    def do_chroot(base, init_mount=true)
      Dir.chroot base.filesystem.chroot
      Dir.chdir "/"
      if init_mount
        m = Mount.new
        base.filesystem.independent_mount_points.each do |mp|
          m.mount mp.src, mp.dest, type: mp.fs
        end
      end
    end

    def switch_guid(base)
      if base.gid
        ::Process::Sys.setgid(base.gid)
        ::Process::Sys.__setgroups(base.groups + [base.gid])
      end
      ::Process::Sys.setuid(base.uid) if base.uid
    end
  end
end
