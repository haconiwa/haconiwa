module Haconiwa
  module Cli
    def self.init(args)
      opt = parse_opts(args, 'HACO_FILE', ignore_catchall: lambda {|o| o['G'].exist? || o['N'].exist? } ) do |o|
        o.string('n', 'name', 'CONTAINER_NAME', "Specify the container name if you want")
        o.string('r', 'root', 'ROOTFS_LOC', "Specify the rootfs location to generate on host")
        o.literal('G', 'global', "Create global config /etc/haconiwa.conf.rb")
        o.literal('N', 'bridge', "Create haconiwa's network bridge")
        o.string('B', 'bridge-name', 'HACONIWA0', "Specify the bridge's name. default to `haconiwa0'")
        o.string('I', 'bridge-ip', '10.0.0.1/24', "Specify the bridge's IP and netmask")
      end

      haconame = opt['n'].exist? ? opt['n'].value : nil
      root     = opt['r'].exist? ? opt['r'].value : nil

      if opt['G'].exist?
        Haconiwa::Generator.generate_global_config
      elsif opt['N'].exist?
        brname = opt['B'].exist? ? opt['B'].value : 'haconiwa0'
        brip   = opt['I'].exist? ? opt['I'].value : '10.0.0.1/24'
        NetworkHandler::Bridge.generate_bridge(brname, brip)
      else
        Haconiwa::Generator.generate_hacofile(opt.catchall.value(0), haconame, root)
      end
    end

    def self.create(args)
      opt = parse_opts(args) do |o|
        o.literal('N', 'no-provision', "Bootstrap but no provisioning")
      end

      Util.get_base(opt.catchall.values).create(opt['N'].exist?)
    end

    def self.provision(args)
      opt = parse_opts(args) do |o|
        o.string('r', 'run-only', 'OP_NAME[,OP_NAME,...]', "Run only specified provision operations by names(splitted with ,)")
      end

      ops = opt['r'].exist? ? opt['r'].value.split(',') : []
      Util.get_base(opt.catchall.values).do_provision(ops)
    end

    def self.archive(args)
      opt = parse_opts(args) do |o|
        o.literal('N', 'no-provision', "Bootstrap but no provisioning")
        o.string('d', 'dest', 'PATH.EXT', "Location where to create archive. Type will be detected by extname")
        o.string('t', 'type', 'TYPE', "Archive type to be created [gzip|bzip2|xz]")
        o.literal('v', 'verbose', "Verbose mode. Passes `-v' to tar command")
        o.literal('n', 'dry-run', "Dry-run mode. Makes dry just on archive phase")
        o.string('O', 'tar-options', 'OPTIONS,OPTIONS...', "Extra option to pass to tar command")
      end

      parsed = {
        no_provision: opt['N'].exist?,
        dest: opt['d'].value,
        type: (opt['t'].exist? ? opt['t'].value : nil),
        verbose: opt['v'].exist?,
        dry_run: opt['n'].exist?,
        tar_options: (opt['O'].exist? ? opt['O'].value.split(',') : nil)
      }

      Util.get_base(opt.catchall.values).archive(parsed)
    end

    def self.run(args)
      load_global_config

      opt = parse_opts(args, 'HACO_FILE [-- COMMAND...]') do |o|
        o.literal('D', 'daemon', "Force the container to be daemon")
        o.literal('T', 'no-daemon', "Force the container not to be daemon, stuck in tty")
        o.literal('b', 'bootstrap', "Kick the bootstrap process on run")
        o.literal('N', 'no-provision', "Skip provisioning, when you intend to kick bootstrap")
      end
      cli_options = {}

      Haconiwa.probe_boottime(PHASE_START_EVAL)
      base, init = Util.get_script_and_eval(opt.catchall.values)
      base.daemonize! if opt['D'].exist?
      base.cancel_daemonize! if opt['T'].exist?

      cli_options[:booting] = opt['b'].exist?
      cli_options[:no_provision] = opt['N'].exist?

      base.run(cli_options, *init)
    end

    def self.attach(args)
      opt = parse_opts(args, 'HACO_FILE [-- COMMAND...]') do |o|
        o.integer('t', 'target', 'PID', "Container's PID to attatch.")
        o.string('n', 'name', 'CONTAINER_NAME', "Container's name. Set if the name is dynamically defined")
        o.string('A', 'allow', 'CAPS[,CAPS...]', "Capabilities to allow attached process. Independent container's own caps")
        o.string('D', 'drop', 'CAPS[,CAPS...]', "Capabilities to drop from attached process. Independent container's own caps")
        o.string('u', 'uid', 'UID_OR_NAME', "The UID to be set to attaching process")
        o.string('g', 'gid', 'GID_OR_NAME', "The GID to be set to attaching process")
      end

      base, exe = Util.get_script_and_eval(opt.catchall.values)

      base.pid  = opt['t'].value if opt['t'].exist?
      base.name = opt['n'].value if opt['n'].exist?
      base.attached_capabilities = Capabilities.new
      if opt['A'].exist? or opt['D'].exist?
        base.attached_capabilities.allow(*opt['A'].value.split(',')) if opt['A'].exist?
        base.attached_capabilities.drop(*opt['D'].value.split(','))  if opt['D'].exist?
      end

      if opt['u'].exist?
        base.uid = opt['u'].value
      end
      if opt['g'].exist?
        base.gid = opt['g'].value
      end

      base.attach(*exe)
    end

    def self.checkpoint(args)
      opt = parse_opts(args, 'HACO_FILE') do |o|
        o.literal('R', 'running', "Create checkpoint of running container. Detect container's PID via hacofile(in case without --target)")
        o.integer('t', 'target', 'PID', "Container's *root* PID to make checkpoint. This implies --running")
      end
      target_pid = if opt['t'].exist?
                     opt['t'].value
                   elsif opt['R'].exist?
                     0
                   else
                     nil
                   end
      Util.get_base(opt.catchall.values).do_checkpoint(target_pid)
    end

    def self.restore(args)
      opt = parse_opts(args, 'HACO_FILE') do |o|
        o.literal('D', 'daemon', "Force the container to be daemon")
        o.literal('T', 'no-daemon', "Force the container not to be daemon, stuck in tty")
      end
      base = Util.get_base(opt.catchall.values)
      base.daemonize! if opt['D'].exist?
      base.cancel_daemonize! if opt['T'].exist?
      base.restore
    end

    def self._restored(args)
      base, init = Util.get_script_and_eval([args[1]])
      base.cancel_daemonize!
      base._restored(args[2])
    end

    def self.reload(args)
      opt = parse_opts(args, '[HACO_FILE]', ignore_catchall: lambda {|o| o['t'].exist? } ) do |o|
        o.integer('t', 'target', 'PPID', "Container's supervisor PID to invoke reload")
        o.string('n', 'name', 'CONTAINER_NAME', "Container's name to be reloaded, default to all the children")
      end

      barn = nil
      if opt.catchall.exist?
        barn = Util.get_base(opt.catchall.values)
      end

      if opt['n'].exist?
        base = barn.find_child_by_name(opt['n'].value)
        raise("Invalid name: #{opt['n'].value}") unless base
        ::Process.kill :SIGHUP, base.ppid
      elsif !barn && opt['t'].exist?
        ::Process.kill :SIGHUP, opt['t'].value.to_i
      else
        barn.containers_real_run.each do |c|
          ::Process.kill :SIGHUP, c.ppid
        end
      end
      STDERR.puts "Reload success"
    end

    def self.kill(args)
      load_global_config

      opt = parse_opts(args) do |o|
        o.integer('t', 'target', 'PID', "Container's PID to kill.")
        o.integer('T', 'timeout', 'SECONDS', "Wait time to be killed. Default to (about) 10 sec")
        o.string('s', 'signal', 'SIGFOO', "Signal name. default to TERM")
      end

      barn, _  = Util.get_script_and_eval(opt.catchall.values)
      barn.pid = opt['t'].value if opt['t'].exist?
      signame  = opt['s'].exist? ? opt['s'].value : "TERM"
      timeout  = opt['T'].exist? ? opt['T'].value : 10
      barn.kill(signame, timeout)
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
  end
end
