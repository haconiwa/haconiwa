module Haconiwa
  class DSLInterfce
    extend ::Forwardable

    attr_accessor :name,
                  :container_pid_file,
                  :workdir,
                  :command,
                  :filesystem,
                  :resource,
                  :cgroup,
                  :cgroupv2,
                  :namespace,
                  :capabilities,
                  :guid,
                  :seccomp,
                  :general_hooks,
                  :async_hooks,
                  :wait_interval,
                  :environ,
                  :attached_capabilities,
                  :signal_handler,
                  :pid,
                  :supervisor_pid,
                  :created_at,
                  :network_mountpoint,
                  :cleaned,
                  :hacofile,
                  :reloadable_attr,
                  :exit_status

    delegate     [:uid,
                  :uid=,
                  :gid,
                  :gid=,
                  :groups,
                  :groups=] => :@guid
  end

  class Barn < DSLInterfce
    def self.define(&b)
      barn = new
      b.call(barn)
      Logger.setup(barn)
      Logger.info("Base setting DSL is evaluated")
      barn
    end

    def define(&b)
      base = Base.new(self)
      b.call(base)
      if find_child_by_name(base.name)
        raise "Duplicated container name: #{base.name}"
      end
      self.containers << base
    end

    def initialize
      @workdir = "/"
      @command = Command.new
      @filesystem = Filesystem.new
      @resource = Resource.new
      @cgroup = CGroup.new
      @cgroupv2 = CGroupV2.new
      @namespace = Namespace.new
      @capabilities = Capabilities.new
      @guid = Guid.new
      @seccomp = Seccomp.new
      @general_hooks = {}
      @async_hooks = []
      @wait_interval = 50
      @environ = {}
      @signal_handler = SignalHandler.new
      @attached_capabilities = nil
      @name = "haconiwa-#{Time.now.to_i}"
      @container_pid_file = nil
      @pid = nil
      @daemon = false
      @network_mountpoint = []
      @reloadable_attr = []
      @cleaned = false
      @bootstrap = @provision = nil

      @waitloop = WaitLoop.new

      @containers = []
    end
    attr_accessor :system_exception, :rid_validator
    attr_reader :containers, :waitloop

    def validate_real_id(&validator)
      @rid_validator = validator
    end

    def containers_real_run
      if containers.empty?
        [Base.new(self)]
      else
        containers
      end
    end

    def find_child_by_name(name)
      containers_real_run.find{|bs| bs.name == name }
    end

    def supervisor_all_pid_file
      names = containers_real_run.map{|b| b.name }.join('-')
      "/var/run/haconiwa-parent-#{names}.pid"
    end

    def init_command=(cmd)
      self.command.init_command = cmd
    end

    def init_command
      self.command.init_command
    end

    # aliases
    def chroot_to(dest)
      self.filesystem.rootfs = Rootfs.new(dest)
    end

    def rootfs_owner(options)
      rootfs.owner_uid = options[:uid]
      rootfs.owner_gid = options[:gid]
    end

    def rootfs
      filesystem.rootfs
    end

    def support_reload(*names)
      names.each do |name|
        unless [:cgroup, :resource].include?(name)
          raise ArgumentError, "Unsupported reload attribute: #{name}"
        end
        @reloadable_attr << name
      end
    end

    def cgroup(v=nil, &blk)
      cg = if v.to_s == "v2"
             @cgroupv2
           else
             @cgroup
           end
      if blk
        cg.defblock = blk
        blk.call(cg)
      end
      cg
    end

    def resource(&blk)
      if blk
        @resource.defblock = blk
        blk.call(@resource)
      end
      @resource
    end

    def add_mount_point(point, options)
      self.namespace.unshare "mount"
      self.filesystem.mount_points << MountPoint.new(point, options)
    end

    def mount_independent_procfs
      self.namespace.unshare "mount"
      self.filesystem.mount_independent("procfs")
    end

    def mount_independent(fs)
      self.namespace.unshare "mount"
      self.filesystem.mount_independent(fs)
    end

    def mount_network_etc(root, options={})
      from = options[:host_root] || '/etc'
      self.network_mountpoint << MountPoint.new("#{from}/resolv.conf", to: "#{root}/etc/resolv.conf")
      self.network_mountpoint << MountPoint.new("#{from}/hosts",       to: "#{root}/etc/hosts")
    end

    def add_general_hook(hookpoint, &b)
      raise("Invalid hook point: #{hookpoint.inspect}") unless LinuxRunner::VALID_HOOKS.include?(hookpoint.to_sym)
      @general_hooks[hookpoint.to_sym] = b
    end

    def add_signal_handler(sig, &b)
      @signal_handler.add_handler(sig, &b)
    end
    alias add_handler add_signal_handler

    def add_async_hook(options={}, &hook)
      @async_hooks << WaitLoop::TimerHook.new(options, &hook)
    end
    alias after_spawn add_async_hook

    def bootstrap
      @bootstrap ||= Bootstrap.new
      yield(@bootstrap) if block_given?
      @bootstrap
    end

    def provision
      @provision ||= Provision.new
      yield(@provision) if block_given?
      @provision
    end

    def default_container_pid_file
      "/var/run/haconiwa-#{@name}.pid"
    end

    def daemonize!
      @daemon = true
    end

    def cancel_daemonize!
      @daemon = false
    end

    def daemon?
      !! @daemon
    end

    def to_container_json
      {
        name: self.name,
        root: self.filesystem.chroot,
        command: self.init_command.join(" "),
        created_at: self.created_at,
        status: "running", # TODO: support status
        metadata: {dummy: "dummy"}, # TODO: support metadata/tagging
        pid: self.pid,
        supervisor_pid: self.supervisor_pid,
      }.to_json
    end

    def validate_non_nil(obj, msg)
      unless obj
        raise(msg)
      end
    end

    def create(opt)
      containers_real_run.each do |c|
        Haconiwa::Logger.puts "Creating rootfs of #{c.name}..."
        c.create(opt)
      end
    end

    def do_provision(ops)
      containers_real_run.each do |c|
        Haconiwa::Logger.puts "Provisioning rootfs of #{c.name}..."
        c.do_provision(ops)
      end
    end

    def start(options, *init_command)
      targets = containers_real_run
      LinuxRunner.new(self).waitall do |_w|
        targets.map do |c|
          pid = ::Process.fork do
            _w.close if _w
            c.start(options, *init_command)
          end
          pid
        end
      end
    end
    alias run start

    def attach(*cmd)
      target = containers_real_run
      if target.size == 1
        c = target.first
        c.copy_attach_context(self)
        c.attach(*cmd)
      else
        puts "Please choose container:"
        target.each_with_index {|c, i| puts "#{i + 1}) #{c.name}" }
        print "Select[1-#{target.size}]: "
        ans = gets
        raise("Invalid input") if ans.to_i < 1
        c = target[ans.to_i - 1]
        c.copy_attach_context(self)
        c.attach(*cmd)
      end
    end

    def kill(signame, timeout)
      containers_real_run.each do |c|
        c.kill(signame, timeout)
      end

      # timeout < 0 means "do not wait"
      return true if timeout < 0

      (timeout * 10).times do
        unless File.exist? supervisor_all_pid_file
          return true
        end
        usleep 100 * 1000
      end
      raise "Kill does not seem to be completed. Check process of PID=#{::File.read supervisor_all_pid_file}"
    end
  end

  class Base < Barn
    def self.define
      raise "Direct call of Haconiwa::Base.define is deprecated. Please rewrite into Haconiwa.define"
    end

    def initialize(barn)
      [
        :@workdir,
        :@command,
        :@filesystem,
        :@resource,
        :@cgroup,
        :@cgroupv2,
        :@namespace,
        :@capabilities,
        :@guid,
        :@seccomp,
        :@general_hooks,
        :@async_hooks,
        :@wait_interval,
        :@environ,
        :@signal_handler,
        :@attached_capabilities,
        :@name,
        :@container_pid_file,
        :@network_mountpoint,
        :@bootstrap,
        :@provision,
        :@reloadable_attr,
      ].each do |varname|
        value = barn.instance_variable_get(varname)
        case value
        when Integer, NilClass, TrueClass, FalseClass
          self.instance_variable_set(varname, value)
        else
          self.instance_variable_set(varname, value.dup)
        end
      end

      @parent = barn
      @waitloop = WaitLoop.new
    end
    attr_reader :parent

    def copy_attach_context(barn)
      [
        :@guid,
        :@attached_capabilities,
      ].each do |varname|
        value = barn.instance_variable_get(varname)
        case value
        when Integer, NilClass, TrueClass, FalseClass
          self.instance_variable_set(varname, value)
        else
          self.instance_variable_set(varname, value.dup)
        end
      end
    end

    def daemon?
      parent.daemon?
    end

    def hacofile
      parent.hacofile
    end

    def skip_bootstrap
      @bootstrap.skip = true
      @provision.skip = true
    end
    alias skip_provision skip_bootstrap

    def pid!
      self.container_pid_file ||= default_container_pid_file
      @pid ||= ::File.read(container_pid_file).to_i
    end

    def ppid
      ::File.read("/proc/#{pid!}/status").split("\n").each do |l|
        next unless l.start_with?("PPid")
        return l.split[1].to_i
      end
    rescue => e
      STDERR.puts e
      nil
    end

    def create(no_provision)
      validate_non_nil(@bootstrap, "`config.bootstrap' block must be defined to create rootfs")
      if @bootstrap.skip
        puts "Bootstrap for #{self.name} marked to skip."
        return
      end

      @bootstrap.boot!(self.rootfs)
      if @provision and !no_provision
        @provision.provision!(self.rootfs)
      end
    end

    def do_provision(ops)
      validate_non_nil(@provision, "`config.provision' block must be defined to run provisioning")
      if @provision.skip
        puts "Provision for #{self.name} marked to skip."
        return
      end

      unless ::File.directory?(self.rootfs.root)
        raise "Rootfs #{rootfs.root} not yet bootstrapped. Run `haconiwa create' before provision."
      end

      @provision.select_ops(ops) unless ops.empty?
      @provision.provision!(self.rootfs)
    end

    def archive(options)
      create(options[:no_provision])
      Archive.new(self, options).do_archive
    end

    def start(options, *init_command)
      if options[:booting]
        Logger.puts "Bootstrapping rootfs on run..."
        create(options[:no_provision])
      end
      self.container_pid_file ||= default_container_pid_file
      LinuxRunner.new(self).run(options, init_command)
    end
    alias run start

    def attach(*run_command)
      self.container_pid_file ||= default_container_pid_file
      LinuxRunner.new(self).attach(run_command)
    end

    def reload(newcg, newcg2, newres)
      LinuxRunner.new(self).reload(self.name, newcg, newcg2, newres, self.reloadable_attr)
    end

    def kill(signame, timeout)
      self.container_pid_file ||= default_container_pid_file
      LinuxRunner.new(self).kill(signame, timeout)
    end
  end

  class Command
    def initialize
      @init_command = ["/bin/bash"] # FIXME: maybe /sbin/init is better
      @stdin = @stdout = @stderr = nil
    end
    attr_reader :init_command, :stdin, :stdout, :stderr

    def init_command=(cmd)
      if cmd.is_a?(Array)
        @init_command = cmd
      else
        @init_command = [cmd]
      end
    end

    # TODO: support options other than file:
    def set_stdin(options)
      @stdin = File.open(options[:file], 'r+')
    end

    def set_stdout(options)
      @stdout = File.open(options[:file], 'a+')
    end

    def set_stderr(options)
      @stderr = File.open(options[:file], 'a+')
    end
  end

  class Resource
    def initialize
      @limits = []
      @defblock = nil
    end
    attr_reader :limits
    attr_accessor :defblock

    def set_limit(type, soft, hard=nil)
      hard ||= soft
      self.limits << [type, soft, hard]
    end
  end

  class CGroup
    def initialize
      @groups = {}
      @groups_by_controller = {}
      @defblock = nil
    end
    attr_reader :groups, :groups_by_controller
    attr_accessor :defblock

    def [](key)
      @groups[key]
    end

    def []=(key, value)
      @groups[key] = value
      c, *attr = key.split('.')
      raise("Invalid cgroup name #{key}") if attr.empty?
      @groups_by_controller[c] ||= []
      @groups_by_controller[c] << [key, attr.join('_')]
      return value
    end

    def to_controllers
      @groups_by_controller.keys.uniq
    end
    alias controllers to_controllers
  end

  class CGroupV2 < CGroup
    def []=(key, value)
      @groups[key] = value
      c, *attr = key.split('.')
      raise("Invalid cgroup name #{key}") if attr.empty?
      return value
    end
  end

  class Capabilities
    DEFAULT_SAFE_CAPABILITIES = %w(
      cap_audit_read
      cap_chown
      cap_dac_override
      cap_fowner
      cap_fsetid
      cap_net_raw
      cap_setgid
      cap_setfcap
      cap_setpcap
      cap_setuid
    )

    def initialize
      @blacklist = []
      @whitelist = DEFAULT_SAFE_CAPABILITIES.dup
    end

    def reset_to_privileged!
      @blacklist.clear
      @whitelist.clear
    end

    def allow(*keys)
      if keys.first == :all
        @whitelist.clear
      else
        @whitelist.concat(keys)
      end
    end

    def whitelist_ids
      @whitelist.map{|n| get_cap_name(n) }
    end

    def blacklist_ids
      @blacklist.map{|n| get_cap_name(n) }
    end

    def drop(*keys)
      @blacklist.concat(keys)
    end

    def acts_as_whitelist?
      ! @whitelist.empty?
    end

    private
    def get_cap_name(n)
      ::Capability.from_name(n)
    rescue => e
      STDERR.puts "Capability name looks invalid: #{n}"
      raise e
    end
  end

  class Namespace
    NS_MAPPINGS = {
      "ipc"    => ::Namespace::CLONE_NEWIPC,
      "net"    => ::Namespace::CLONE_NEWNET,
      "mount"  => ::Namespace::CLONE_NEWNS,
      "pid"    => ::Namespace::CLONE_NEWPID,
      "user"   => ::Namespace::CLONE_NEWUSER,
      "uts"    => ::Namespace::CLONE_NEWUTS,
    }

    def initialize
      @namespaces = {}
      @ns_to_path = {}
      @uid_mapping = nil
      @gid_mapping = nil
    end
    attr_reader :namespaces

    def unshare(ns, options={})
      flag = to_bit(ns)
      if flag == ::Namespace::CLONE_NEWPID
        @use_pid_ns = true
      end
      @namespaces[flag] = options
    end

    def flag?(flag)
      @namespaces.has_key? to_bit(flag)
    end

    def active_namespaces
      @namespaces.keys
    end

    def enter(ns, path_or_opt)
      path = case path_or_opt
             when Hash
               path_or_opt.delete(:via)
             else
               path_or_opt
             end
      raise("Invalid option") unless path
      flag = to_bit(ns)
      unshare(flag)
      @ns_to_path[flag] = path
    end

    def set_uid_mapping(options)
      unshare "user"
      if (options.keys & [:min, :max, :offset]).size != 3
        raise("Invalid mapping option: #{options.inspect}")
      end
      @uid_mapping = options
    end

    def set_gid_mapping(options)
      unshare "user"
      if (options.keys & [:min, :max, :offset]).size != 3
        raise("Invalid mapping option: #{options.inspect}")
      end
      @gid_mapping = options
    end

    def use_guid_mapping?
      !!@uid_mapping or !!@gid_mapping
    end

    def enter_existing_pidns?
      @ns_to_path.has_key? ::Namespace::CLONE_NEWPID
    end

    attr_reader :use_pid_ns, :ns_to_path, :uid_mapping, :gid_mapping

    def use_netns(name)
      enter("net", "/var/run/netns/#{name}")
    end

    def setns_on_run?
      !@ns_to_path.empty?
    end

    def to_bit(ns)
      case ns
      when String, Symbol
        NS_MAPPINGS[ns.to_s]
      when Integer
        ns
      end
    end

    def to_flag
      active_namespaces.inject(0x00000000) { |dst, flag|
        dst |= flag
      }
    end

    def to_flag_for_unshare
      f = to_flag_without_pid_and_user
      @ns_to_path.keys.each do |mask|
        f &= (~mask)
      end
      f
    end

    def to_flag_without_pid_and_user
      to_flag & (~(::Namespace::CLONE_NEWPID | ::Namespace::CLONE_NEWUSER))
    end
  end

  class Guid
    attr_reader :uid,
                :gid,
                :groups

    def initialize
      @uid = @gid = nil
      @groups = []
    end

    def uid=(newid)
      if newid.is_a?(String) and newid !~ /^\d+$/
        @uid = ::Process::UID.from_name newid
      else
        @uid = newid.to_i
      end
    end

    def gid=(newid)
      if newid.is_a?(String) and newid !~ /^\d+$/
        @gid = ::Process::GID.from_name newid
      else
        @gid = newid.to_i
      end
    end

    def groups=(newgroups)
      @groups.clear
      newgroups.each do |newid|
        if newid.is_a?(String)
          @groups << ::Process::GID.from_name(newid)
        else
          @groups << newid
        end
      end
      @groups
    end
  end

  class Seccomp
    def initialize
      @def_action = nil
      @defblock = nil
    end
    attr_accessor :def_action, :defblock

    def filter(options={}, &blk)
      @def_action = options[:default]
      raise("default: must be specified to filter") unless @def_action
      @defblock = blk
    end
  end

  class Rootfs
    def initialize(rootpath, options={})
      @root = rootpath.to_str if rootpath
      @owner_uid = options[:owner_uid] || 0
      @owner_gid = options[:owner_gid] || 0
    end
    attr_accessor :root, :owner_uid, :owner_gid

    def to_s;   self.root; end
    def to_str; self.root; end

    def to_owner_options
      opts = []
      opts << "uid=#{@owner_uid}" if @owner_uid != 0
      opts << "gid=#{@owner_gid}" if @owner_gid != 0

      opts.empty? ? {} : {options: opts.join(",")}
    end
  end

  class Filesystem
    def initialize
      @mount_points = []
      @independent_mount_points = []
      @rootfs = Rootfs.new(nil)
    end
    attr_accessor :mount_points,
                  :independent_mount_points,
                  :rootfs

    FS_TO_MOUNT = {
      "procfs" => ["proc", "proc", "/proc"],
      "sysfs"  => ["sysfs", "sysfs", "/sys"],
      "devtmpfs" => ["devtmpfs", "devtmpfs", "/dev"],
      "devpts" => ["devpts", "devpts", "/dev/pts"],
      "shm"    => ["tmpfs", "tmpfs", "/dev/shm"],
    }

    def chroot
      self.rootfs.root
    end

    def mount_independent(fs)
      params = FS_TO_MOUNT[fs]
      raise("Unsupported: #{fs}") unless params

      self.independent_mount_points << MountPoint.new(params[1], to: params[2], fs: params[0])
    end
  end

  class MountPoint
    def initialize(point, options={})
      @src = point.to_s
      @dest = options.delete(:to)
      @dest = @dest.to_s if @dest
      @fs = options.delete(:fs)
      @options = options
    end
    attr_accessor :src, :dest, :fs, :options

    def normalized_src(cwd="/")
      if @src.start_with?('/')
        @src
      # These filesystems do not need a real src directory
      elsif %w(tmpfs devtmpfs proc sysfs devpts).include?(@fs.to_s)
        @src
      else
        fullpath = ExpandPath.expand [cwd, @src].join("/")
        File.exist?(fullpath) ? fullpath : @src
      end
    end
  end

  def self.define(&b)
    Barn.define(&b)
  end
end
