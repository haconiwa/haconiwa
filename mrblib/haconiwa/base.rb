module Haconiwa
  class DSLObject
    attr_accessor :name,
                  :init_command,
                  :container_pid_file,
                  :filesystem,
                  :resource,
                  :cgroup,
                  :namespace,
                  :capabilities,
                  :attached_capabilities,
                  :signal_handler,
                  :pid,
                  :supervisor_pid,
                  :created_at,
                  :etcd_name,
                  :network_mountpoint,
                  :cleaned

    attr_reader   :uid,
                  :gid,
                  :groups

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

    def uid=(newid)
      if newid.is_a?(String)
        @uid = ::Process::UID.from_name newid
      else
        @uid = newid
      end
    end

    def gid=(newid)
      if newid.is_a?(String)
        @gid = ::Process::GID.from_name newid
      else
        @gid = newid
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
  end

  class Barn < DSLObject
    attr_accessor :bases

    def self.define(&b)
      barn = new
      b.call(barn)
      barn
    end

    def initialize
      @filesystem = Filesystem.new
      @resource = Resource.new
      @cgroup = CGroup.new
      @namespace = Namespace.new
      @capabilities = Capabilities.new
      @signal_handler = SignalHandler.new(self)
      @attached_capabilities = nil
      @name = "haconiwa-#{Time.now.to_i}"
      @init_command = ["/bin/bash"] # FIXME: maybe /sbin/init is better
      @container_pid_file = nil
      @pid = nil
      @daemon = false
      @uid = @gid = nil
      @groups = []
      @network_mountpoint = []
      @cleaned = false
    end

    def add_handler(sig, &b)
      @signal_handler.add_handler(sig, &b)
    end
  end

  class Base < DSLObject
    def self.define(&b)
      base = new
      b.call(base)
      base
    end

    def initialize(barn)
      # copy parent parameters to each child
      [:init_command,
       :filesystem,
       :resource,
       :cgroup,
       :namespace,
       :capabilities,
       :network_mountpoint,
       :uid,
       :gid,
       :groups].each do |attr|
        self.send("#{attr}=", barn.send(attr))
      end
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

    def start(*init_command)
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
    def initialize
      @blacklist = []
      @whitelist = []
    end

    def allow(*keys)
      if keys.first == :all
        @whitelist.clear
      else
        @whitelist.concat(keys)
      end
    end

    def whitelist_ids
      @whitelist.map{|n| ::Capability.from_name(n) }
    end

    def blacklist_ids
      @blacklist.map{|n| ::Capability.from_name(n) }
    end

    def drop(*keys)
      @blacklist.concat(keys)
    end

    def acts_as_whitelist?
      ! @whitelist.empty?
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
      @use_ns = []
      @ns_to_path = {}
      @uid_mapping = nil
      @gid_mapping = nil
    end

    def unshare(ns)
      flag = to_bit(ns)
      if flag == ::Namespace::CLONE_NEWPID
        @use_pid_ns = true
      end
      @use_ns << flag
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
      @use_ns.inject(0x00000000) { |dst, flag|
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
