module Haconiwa
  class Bootstrap
    def initialize
    end
    attr_accessor :strategy, :root,
                  :project_name, :os_type,
                  :arch, :variant, :components, :debian_release, :mirror_url

    def boot!(r)
      self.root = Pathname.new(r)
      self.project_name ||= File.basename(root.to_s)
      if File.directory?(root)
        log("Directory #{root} already bootstrapped.")
        return true
      end

      case strategy
      when "lxc", "lxc-create"
        bootstrap_with_lxc_template
      when "debootstrap"
        bootstrap_with_debootstrap
      else
        raise "Unsupported: #{strategy}"
      end
    end

    def bootstrap_with_lxc_template
      cmd = RunCmd.new("bootstrap.lxc")
      log("Start bootstrapping rootfs with lxc-create...")

      unless system "which lxc-create >/dev/null"
        raise "lxc-create command may not be installed yet. Please install via your package manager."
      end

      cmd.run(sprintf("lxc-create -n %s -t %s --dir %s", project_name, os_type, root.to_str))
      log("Success!")
      return true
    end

    def bootstrap_with_debootstrap
      cmd = RunCmd.new("bootstrap.debootstrap")
      log("Start bootstrapping rootfs with debootstrap...")

      unless system "which debootstrap >/dev/null"
        raise "debootstrap command may not be installed yet. Please install via your package manager."
      end

      self.arch ||= "amd64" # TODO: detection
      self.components ||= "main"
      self.mirror_url ||= "http://ftp.us.debian.org/debian/"

      cmd.run(sprintf(
                "debootstrap --arch=%s --variant=%s --components=%s %s %s %s",
                arch, variant, components, debian_release, root.to_str, mirror_url
              ))
      log("Success!")
      return true
    end

    private
    def log(msg)
      $stderr.puts msg.green
    end
  end
end
