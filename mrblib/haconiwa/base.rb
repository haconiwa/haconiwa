module Haconiwa
  class Base
    extend ::Forwardable

    attr_accessor :name,
                  :container_pid_file,
                  :filesystem,
                  :resource,
                  :cgroup,
                  :namespace,
                  :capabilities,
                  :guid,
                  :attached_capabilities,
                  :signal_handler,
                  :pid,
                  :supervisor_pid,
                  :created_at,
                  :etcd_name,
                  :network_mountpoint,
                  :cleaned

    attr_reader   :init_command,
                  :waitloop

    delegate     [:uid,
                  :uid=,
                  :gid,
                  :gid=,
                  :groups,
                  :groups=] => :@guid

    def self.define(&b)
      base = new
      b.call(base)
      Logger.setup(base)
      Logger.info("Base setting DSL is evaluated")
      base
    end

    def initialize
      @filesystem = Filesystem.new
      @resource = Resource.new
      @cgroup = CGroup.new
      @namespace = Namespace.new
      @capabilities = Capabilities.new
      @guid = Guid.new
      @signal_handler = SignalHandler.new
      @attached_capabilities = nil
      @name = "haconiwa-#{Time.now.to_i}"
      @init_command = ["/bin/bash"] # FIXME: maybe /sbin/init is better
      @container_pid_file = nil
      @pid = nil
      @daemon = false
      @network_mountpoint = []
      @cleaned = false

      @waitloop = WaitLoop.new
    end

    def init_command=(cmd)
      if cmd.is_a?(Array)
        @init_command = cmd
      else
        @init_command = [cmd]
      end
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

    def add_signal_handler(sig, &b)
      @signal_handler.add_handler(sig, &b)
    end
    alias add_handler add_signal_handler

    def after_spawn(options={}, &hook)
      self.waitloop.hooks << WaitLoop::TimerHook.new(options, &hook)
    end

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

    def create(no_provision)
      validate_non_nil(@bootstrap, "`config.bootstrap' block must be defined to create rootfs")
      @bootstrap.boot!(self.rootfs)
      if @provision and !no_provision
        @provision.provision!(self.rootfs)
      end
    end

    def do_provision(ops)
      unless ::File.directory?(self.rootfs.root)
        raise "Rootfs #{rootfs.root} not yet bootstrapped. Run `haconiwa create' before provision."
      end

      validate_non_nil(@provision, "`config.provision' block must be defined to run provisioning")
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
      LinuxRunner.new(self).run(init_command)
    end
    alias run start

    def attach(*run_command)
      self.container_pid_file ||= default_container_pid_file
      LinuxRunner.new(self).attach(run_command)
    end

    def kill(signame)
      self.container_pid_file ||= default_container_pid_file
      LinuxRunner.new(self).kill(signame)
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
        etcd_name: self.etcd_name,
        root: self.filesystem.chroot,
        command: self.init_command.join(" "),
        created_at: self.created_at,
        status: "running", # TODO: support status
        metadata: {dummy: "dummy"}, # TODO: support metadata/tagging
        pid: self.pid,
        supervisor_pid: self.supervisor_pid,
      }.to_json
    end

    def etcd_key
      "haconiwa.mruby.org/#{etcd_name}/#{name}"
    end

    def validate_non_nil(obj, msg)
      unless obj
        raise(msg)
      end
    end
  end

  class Resource
    def initialize
      @limits = []
    end
    attr_reader :limits

    def set_limit(type, value)
      self.limits << [type, value]
    end
  end

  class CGroup
    def initialize
      @groups = {}
      @groups_by_controller = {}
    end
    attr_reader :groups, :groups_by_controller

    def [](key)
      @groups[key]
    end

    def []=(key, value)
      @groups[key] = value
      c, attr = key.split('.')
      raise("Invalid cgroup name #{key}") unless attr
      @groups_by_controller[c] ||= Array.new
      @groups_by_controller[c] << [key, attr]
      return value
    end

    def to_controllers
      @groups_by_controller.keys.uniq
    end
    alias controllers to_controllers
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

  class Rootfs
    def initialize(rootpath, options={})
      @root = rootpath.to_str
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
      @src = point
      @dest = options.delete(:to)
      @fs = options.delete(:fs)
      @options = options
    end
    attr_accessor :src, :dest, :fs, :options
  end

  def self.define(&b)
    Base.define(&b)
  end
end
