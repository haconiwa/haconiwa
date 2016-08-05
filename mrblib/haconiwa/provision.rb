module Haconiwa
  class Provision
    def initialize
    end
    attr_accessor :root, :strategy, :extra_bind # TODO
    attr_reader   :shell

    def shell=(shell)
      self.strategy = "shell"
      @shell = shell
    end

    def provision!(r)
      self.root = Pathname.new(r.to_s)

      p = self
      pid = Process.fork do
        p.chroot_into(p.root)

        case strategy = p.strategy
        when "shell"
          p.provision_with_shell
        else
          raise "Unsupported: #{strategy}"
        end
      end
      pid, s = *Process.waitpid2(pid)

      if s.success?
        log "Success!"
        return true
      else
        log "Provisioning failed: #{s.inspect}!"
        return false
      end
    end

    def provision_with_shell
      cmd = RunCmd.new("provison.shell")

      log("Start provisioning with shell script...")
      cmd.run_with_input("/bin/bash -xe", self.shell)
    end

    def chroot_into(root)
      m = ::Mount.new
      ::Namespace.unshare ::Namespace::CLONE_NEWNS

      m.make_private "/"
      Dir.chdir root
      Dir.chroot root
      m.mount "proc",     "/proc", type: "proc"
      m.mount "devtmpfs", "/dev",  type: "devtmpfs"
      m.mount "sysfs",    "/sys",  type: "sysfs"
      m.mount "tmpfs",    "/tmp",  type: "tmpfs"
    end

    private
    def log(msg)
      $stderr.puts msg.green
    end
  end
end
