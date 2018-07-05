module Haconiwa
  class CRIUService
    def initialize(base)
      @base = base
    end

    def create_checkpoint
      c = CRIU.new
      c.set_images_dir "/tmp/criu_test"
      c.set_service_address "/var/run/criu_service.socket"
      c.set_log_file "-"
      c.set_log_level 5
      c.set_shell_job true

      pid = Process.fork do
        context = ::Seccomp.new(default: :allow) do |rule|
          rule.trace(:listen, 0)
        end
        context.load

        Dir.chdir ExpandPath.expand([@base.filesystem.chroot, @base.workdir].join('/'))
        Dir.chroot @base.filesystem.chroot
        Exec.execve(@base.environ, *@base.init_command)
      end

      ret = ::Seccomp.start_trace(pid) do |syscall, _pid, ud|
        name = ::Seccomp.syscall_to_name(syscall)
        Haconiwa::Logger.puts "[#{_pid}]: syscall #{name}(##{syscall}) called. (ud: #{ud}), dump the process image."

        begin
          c.set_pid _pid
          c.dump
        rescue => e
          Haconiwa::Logger.puts "[#{_pid}]: dump failed: #{e.class}, #{e.message}"
        else
          Haconiwa::Logger.puts "[#{_pid}]: dumped!!"
        end
      end
      Haconiwa::Logger.puts ret
    end

    def restore
      images_dir = "/tmp/criu_test"
      ::Exec.execve(ENV, "/usr/local/sbin/criu", "restore", "--shell-job", "-D", images_dir)
    end
  end
end
