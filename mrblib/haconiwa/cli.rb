module Haconiwa
  module Cli
    def self.init(args)
      opt = parse_opts(args, 'HACO_FILE', ignore_catchall: lambda {|o| o['G'].exist? } ) do |o|
        o.string('n', 'name', 'CONTAINER_NAME', "Specify the container name if you want")
        o.string('r', 'root', 'ROOTFS_LOC', "Specify the rootfs location to generate on host")
        o.literal('G', 'global', "Create global config /etc/haconiwa.conf.rb")
      end

      haconame = opt['n'].exist? ? opt['n'].value : nil
      root     = opt['r'].exist? ? opt['r'].value : nil

      if opt['G'].exist?
        Haconiwa::Generator.generate_global_config
      else
        Haconiwa::Generator.generate_hacofile(opt.catchall.value(0), haconame, root)
      end
    end

    def self.create(args)
      opt = parse_opts(args) do |o|
        o.literal('N', 'no-provision', "Bootstrap but no provisioning")
      end

      get_base(opt.catchall.values).create(opt['N'].exist?)
    end

    def self.provision(args)
      opt = parse_opts(args) do |o|
        o.string('r', 'run-only', 'OP_NAME[,OP_NAME,...]', "Run only specified provision operations by names(splitted with ,)")
      end

      ops = opt['r'].exist? ? opt['r'].value.split(',') : []
      get_base(opt.catchall.values).do_provision(ops)
    end

    def self.run(args)
      load_global_config

      opt = parse_opts(args, 'HACO_FILE [-- COMMAND...]') do |o|
        o.literal('D', 'daemon', "Force the container to be daemon")
      end

      base, init = get_script_and_eval(opt.catchall.values)
      base.daemonize! if opt['D'].exist?
      base.run(*init)
    end

    def self.attach(args)
      opt = parse_opts(args, 'HACO_FILE [-- COMMAND...]') do |o|
        o.integer('t', 'target', 'PID', "Container's PID to attatch.")
        o.string('n', 'name', 'CONTAINER_NAME', "Container's name. Set if the name is dynamically defined")
        o.string('A', 'allow', 'CAPS[,CAPS...]', "Capabilities to allow attached process. Independent container's own caps")
        o.string('D', 'drop', 'CAPS[,CAPS...]', "Capabilities to drop from attached process. Independent container's own caps")
      end

      base, exe = get_script_and_eval(opt.catchall.values)

      base.pid  = opt['t'].value if opt['t'].exist?
      base.name = opt['n'].value if opt['n'].exist?
      base.attached_capabilities = Capabilities.new
      if opt['A'].exist? or opt['D'].exist?
        base.attached_capabilities.allow(*opt['A'].value.split(',')) if opt['A'].exist?
        base.attached_capabilities.drop(*opt['D'].value.split(','))  if opt['D'].exist?
      end

      base.attach(*exe)
    end

    def self.ps(args)
      load_global_config
      opt = Argtable.new
      opt.literal('h', 'help', "Show help")
      opt.parse(args)

      if opt['h'].exist?
        opt.glossary
        exit
      end

      Haconiwa::ProcessList.new.show
    end

    def self.kill(args)
      load_global_config

      opt = parse_opts(args) do |o|
        o.integer('t', 'target', 'PID', "Container's PID to kill.")
        o.string('s', 'signal', 'SIGFOO', "Signal name. default to TERM")
      end

      base, _  = get_script_and_eval(opt.catchall.values)
      base.pid = opt['t'].value if opt['t'].exist?
      signame  = opt['s'].exist? ? opt['s'].value : "TERM"
      base.kill(signame)
    end

    def self.revisions
      puts "mgem and mruby revisions:"
      puts "--------"
      puts Haconiwa.mrbgem_revisions.to_a.map{|a| sprintf "%-24s%s", *a }.join("\n")
    end

    private

    GLOBAL_CONFIG_FILE = "/etc/haconiwa.conf.rb"
    def self.load_global_config
      # The hook of load global config
      if File.exist?(GLOBAL_CONFIG_FILE)
        eval(File.read GLOBAL_CONFIG_FILE)
      end
    end

    def self.parse_opts(args, hacofile_opt='HACO_FILE', options={}, &b)
      opt = Argtable.new
      b.call(opt)

      # The default options
      opt.literal('h', 'help', "Show help")
      opt.enable_catchall(hacofile_opt, 'Put the config file at the end of command', 32)

      # The defaut behaviours
      e = opt.parse(args)

      if opt['h'].exist?
        opt.glossary
        exit
      end

      if e > 0
        opt.glossary
        exit 1
      end

      ignore_catchall = if options[:ignore_catchall]
                          options[:ignore_catchall][opt]
                        else
                          false
                        end

      if !ignore_catchall and !opt.catchall.exist?
        STDERR.puts "Please specify haco file name"
        opt.glossary
        exit 1
      end

      return opt
    end

    def self.get_base(args)
      script = File.read(args[0])
      return Kernel.eval(script)
    end

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
