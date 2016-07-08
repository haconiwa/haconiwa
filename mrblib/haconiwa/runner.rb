module Haconiwa
  class Runner
  end

  class LinuxRunner < Runner
    def initialize(base)
      @base = base
    end

    def run(init_command)
      base = @base
      jail_pid(base)
      pid = Process.fork do
        apply_namespace(base)
        apply_filesystem(base)
        apply_cgroup(base)
        apply_capability(base)
        do_chroot(base)

        Exec.exec(base.init_command || "/bin/bash")
      end

      pid, status = Process.waitpid2 pid
      if status.success?
        puts "Container successfullly exited: #{status.inspect}"
      else
        puts "Container failed: #{status.inspect}"
      end
    end

    def jail_pid(base)
      if base.namespace.use_pid_ns
        ::Namespace.unshare(::Namespace::CLONE_NEWPID)
      end
    end

    def apply_namespace(base)
      ::Namespace.unshare(base.namespace.to_ns_flag)
    end

    def apply_filesystem(base)
      m = Mount.new
      m.make_private "/"
      base.filesystem.mount_points.each do |mp|
        case
        when mp.fs
          m.mount mp.src, mp.dest, type: mp.fs
        else
          m.bind_mount mp.src, mp.dest
        end
      end
    end

    def apply_cgroup(base)
    end

    # TODO: check inheritable
    #       and handling when it is non-root
    def apply_capability(base)
      if base.capabilities.acts_as_whitelist?
        ids = base.capabilities.whitelist_ids
        (0..38).each do |cap|
          break unless ::Capability.supported? cap
          next if ids.include?(cap)
          ::Capability.drop_bound cap
        end
      else
        base.capabilities.blacklist_ids.each do |cap|
          ::Capability.drop_bound cap
        end
      end
    end

    def do_chroot(base)
      Dir.chroot base.filesystem.chroot
      Dir.chdir "/"
      if base.filesystem.mount_independent_procfs
        Mount.new.mount("proc", "/proc", type: "proc")
      end
    end

    # TODO: resource limit and setguid
  end
end
