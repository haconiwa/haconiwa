module Haconiwa
  class Base
    attr_accessor :name,
                  :container_pid_file,
                  :filesystem,
                  :resource,
                  :cgroup,
                  :namespace,
                  :capabilities,
                  :attached_capabilities,
                  :signal_handler,
                  :pid

    attr_reader   :init_command,
                  :uid,
                  :gid,
                  :groups

    def self.define(&b)
      base = new
      b.call(base)
      base
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
      self.filesystem.chroot = dest
    end

    def root
      filesystem.chroot
    end

    def add_mount_point(point, options)
      self.namespace.unshare "mount"
      self.filesystem.mount_points << MountPoint.new(point, options)
    end

    def mount_independent_procfs
      self.namespace.unshare "mount"
      self.filesystem.mount_independent_procfs = true
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

    def add_handler(sig, &b)
      @signal_handler.add_handler(sig, &b)
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
      @bootstrap.boot!(self.root)
      if @provision and !no_provision
        @provision.provision!(self.root)
      end
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

    def daemon?
      !! @daemon
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
      @netns_name = nil
    end

    def unshare(ns)
      flag = case ns
             when String, Symbol
               NS_MAPPINGS[ns.to_s]
             when Integer
               ns
             end
      if flag == ::Namespace::CLONE_NEWPID
        @use_pid_ns = true
      end
      @use_ns << flag
    end
    attr_reader :use_pid_ns

    def use_netns(name)
      @netns_name = name
    end

    def to_flag
      @use_ns.inject(0x00000000) { |dst, flag|
        dst |= flag
      }
    end

    def to_flag_without_pid
      to_flag & (~(::Namespace::CLONE_NEWPID))
    end
  end

  class Filesystem
    def initialize
      @mount_points = []
      @mount_independent_procfs = false
    end
    attr_accessor :chroot, :mount_points,
                  :mount_independent_procfs
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
