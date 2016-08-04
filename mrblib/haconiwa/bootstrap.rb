module Haconiwa
  class Bootstrap
    def initialize
    end
    attr_accessor :strategy, :root,
                  :project_name, :os_type

    def boot!(root)
      self.root = root
      if File.directory?(root)
        log("Directory #{root} already bootstrapped.")
        return true
      end

      cmd = RunCmd.new("bootstrap")
      case strategy
      when "lxc", "lxc-create"
        bootstrap_with_lxc_template(cmd)
      else
        raise "Unsupported: #{strategy}"
      end
    end

    def bootstrap_with_lxc_template(cmd)
      unless system "which lxc-create"
        raise "lxc-create command may not be installed yet. Please install via your package manager."
      end

      cmd.run(sprintf("lxc-create -n %s -t %s --dir %s", project_name, os_type, root))
      return true
    end

    private
    def log(msg)
      $stderr.puts msg.green
    end
  end
end
