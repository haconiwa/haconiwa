module Haconiwa
  module Cli
    def self.run(args)
      base, init = get_script_and_eval(args)
      base.run(*init)
    end

    # def self.attach(args)
    #   require 'optparse'
    #   opt = OptionParser.new
    #   pid = nil
    #   name = nil
    #   allow = nil
    #   drop = nil

    #   opt.program_name = "haconiwa attach"
    #   opt.on('-t', '--target PID', "Container's PID to attatch. If not set, use pid file of definition") {|v| pid = v }
    #   opt.on('-n', '--name CONTAINER_NAME', "Container's name. Set if the name is dynamically defined") {|v| name = v }
    #   opt.on('--allow CAPS[,CAPS...]', "Capabilities to allow attached process. Independent container's own caps") {|v| allow = v.split(',') }
    #   opt.on('--drop CAPS[,CAPS...]', "Capabilities to drop from attached process. Independent container's own caps") {|v| drop = v.split(',') }
    #   args = opt.parse(args)

    #   base, exe = get_script_and_eval(args)
    #   base.pid = pid if pid
    #   base.name = name if name
    #   if allow || drop
    #     base.attached_capabilities = Capabilities.new
    #     base.attached_capabilities.allow(*allow) if allow
    #     base.attached_capabilities.drop(*drop) if drop
    #   end

    #   base.attach(*exe)
    # end

    private

    def self.get_script_and_eval(args)
      script = File.read(args[0])
      exe    = args[1..-1]
      if exe.first == "--"
        exe.shift
      end

      return [Kernel.eval(script), exe]
    end
  end
end
