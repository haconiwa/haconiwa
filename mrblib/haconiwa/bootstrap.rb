module Haconiwa
  class Bootstrap
    attr_reader :strategy
    attr_accessor :root,
                  :project_name, :os_type, # for LXC
                  :arch, :variant, :components, :debian_release, :mirror_url, # for Deb
                  :git_url, :git_options, # for git clone
                  :archive_path, :tar_options # for unarchive

    def strategy=(name_or_instance)
      @strategy = if name_or_instance.is_a?(String) || name_or_instance.is_a?(Symbol)
                    case name_or_instance.to_s
                    when "lxc", "lxc-create"
                      BootWithLXCTemplate.new
                    when "debootstrap"
                      BootWithDebootstrap.new
                    when "git_clone"
                      BootWithDebootstrap.new
                    else
                      raise "Unsupported bootstrap strategy: #{name_or_instance}"
                    end
                  else
                    name_or_instance
                  end
    end

    def boot!(r)
      self.root = r
      self.project_name ||= File.basename(root.to_str)
      if File.directory?(root.to_str)
        log("Directory #{root.to_str} already bootstrapped. Skip.")
        return true
      end

      # Requires duck typing bootstrap class
      self.strategy.bootstrap(self)

      teardown
    end

    class BootWithLXCTemplate
      def bootstrap(boot)
        cmd = RunCmd.new("bootstrap.lxc")
        boot.log("Start bootstrapping rootfs with lxc-create...")

        unless system "which lxc-create >/dev/null"
          raise "lxc-create command may not be installed yet. Please install via your package manager."
        end

        cmd.run(sprintf("lxc-create -n %s -t %s --dir %s", boot.project_name, boot.os_type, boot.root.to_str))
        boot.log("Success!")
        return true
      end
    end

    class BootWithDebootstrap
      def bootstrap(boot)
        cmd = RunCmd.new("bootstrap.debootstrap")
        boot.log("Start bootstrapping rootfs with debootstrap...")

        unless system "which debootstrap >/dev/null"
          raise "debootstrap command may not be installed yet. Please install via your package manager."
        end

        boot.arch ||= "amd64" # TODO: detection
        boot.components ||= "main"
        boot.mirror_url ||= "http://ftp.us.debian.org/debian/"

        cmd.run(sprintf(
                  "debootstrap --arch=%s --variant=%s --components=%s %s %s %s",
                  boot.arch, boot.variant, boot.components, boot.debian_release, boot.root.to_str, boot.mirror_url
                ))
        boot.log("Success!")
        return true
      end
    end

    class BootWithGitClone
      def bootstrap(boot)
        cmd = RunCmd.new("bootstrap.git_clone")
        boot.log("Cloning rootfs from #{boot.git_url}...")

        unless system "which git >/dev/null"
          raise "mmm... you seem not to have git."
        end

        boot.git_options ||= []

        cmd.run(sprintf("git clone %s %s %s", boot.git_options.join(' '), boot.git_url, boot.root.to_str))
        boot.log("Success!")
        return true
      end
    end

    class BootWithUnarchive
      def bootstrap(boot)
        cmd = RunCmd.new("bootstrap.unarchive")
        boot.log("Extracting rootfs...")

        boot.tar_options ||= []
        boot.tar_options << "-x"
        boot.tar_options << detect_zip_type(boot.archive_path)
        boot.tar_options = boot.tar_options.compact.uniq
        boot.tar_options << "-f"
        boot.tar_options << boot.archive_path
        boot.tar_options << "-C"
        boot.tar_options << boot.root.to_str

        cmd.run(sprintf("mkdir -p %s", boot.root.to_str))
        cmd.run(sprintf("tar %s", boot.tar_options.join(' '))
        boot.log("Success!")
        return true
      end

      private
      def detect_zip_type(path)
        case ::File.extname(path)
        when ".gz", ".tgz"
          "-z"
        when ".bz2"
          "-j"
        when ".xz"
          "-J"
        else
          log "[Warning] Archive type detection failed: #{path}. Skip"
          nil
        end
      end
    end

    def log(msg)
      $stderr.puts msg.green
    end

    private
    def teardown
      if root.owner_uid != 0 or root.owner_gid != 0
        cmd = RunCmd.new("bootstrap.teardown")
        cmd.run "chown -R #{root.owner_uid}:#{root.owner_gid} #{root.root.to_s}"
      end
    end
  end
end
