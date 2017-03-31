module Haconiwa
  module Generator
    BASE_TEMPLATE = <<-RUBY
# -*- mode: ruby -*-
Haconiwa.define do |config|
  # The container name and container's hostname:
  config.name = !__NAME__!
  # The first process when invoking haconiwa run:
  config.init_command = "/bin/bash"
  # If your first process is a daemon, please explicitly daemonize by:
  # config.daemonize!

  # If you want to emit command's stdout/err to files, uncomment here
  # This is active only on daemon mode:
  # config.command.set_stdout(file: "/var/log/haconiwa-container.stdout")
  # config.command.set_stderr(file: "/var/log/haconiwa-container.stderr")

  # The rootfs location on your host OS
  # Pathname class is useful:
  root = Pathname.new(!__ROOT__!)
  config.chroot_to root

  # The bootstrap process...
  # Choose lxc, debootstrap, git-clone, shell or mruby:
  config.bootstrap do |b|
    b.strategy = "lxc"
    b.os_type  = "alpine"

    # b.strategy = "debootstrap"
    # b.variant = "minbase"
    # b.debian_release = "jessie"
  end
  # Check that the required binary is installed(lxc-create / debootstrap)

  # The provisioning process...
  # You can declare run_shell step by step:
  config.provision do |p|
    p.run_shell <<-SHELL
apk add --update bash
    SHELL
  end

  # mount point configuration:
  config.add_mount_point "tmpfs", to: root.join("tmp"), fs: "tmpfs"

  # Share network etc files from host to contianer
  # You can reuse /etc/netns/${netnsname}/* files:
  config.mount_network_etc(root, host_root: "/etc")

  # more mount point configuration example:
  # config.add_mount_point root, to: root, readonly: true
  # config.add_mount_point "/lib64", to: root.join("lib64"), readonly: true

  # Re-mount specific filesystems under new container namespace
  # These are recommended when namespaces such as pid and net are unshared:
  config.mount_independent "procfs"
  config.mount_independent "sysfs"
  config.mount_independent "devtmpfs"
  config.mount_independent "devpts"
  config.mount_independent "shm"

  # The namespaces to unshare:
  config.namespace.unshare "mount"
  config.namespace.unshare "ipc"
  config.namespace.unshare "uts"
  config.namespace.unshare "pid"

  # You can use existing namespace via symlink file. e.g.:
  # config.namespace.enter "net", via: "/var/run/netns/sample001"

  # The cgroup configuration example:
  # config.cgroup["cpu.cfs_period_us"] = 100000
  # config.cgroup["cpu.cfs_quota_us"]  =  30000

  # The linux kernel capability:
  # Haconiwa has default capability whitelist and applies it when there's no config
  # If you want to use customized blacklist, first uncomment below:
  # config.capabilities.reset_to_privileged!

  # Then declare:
  # config.capabilities.allow :all
  # config.capabilities.drop "cap_sys_time"
  # config.capabilities.drop "cap_kill"

  # When you use whitelist capability, set:
  # config.capabilities.allow "cap_sys_admin"

  # Specify uid/gid who owns container process:
  # config.uid = "vagrant"
  # config.gid = "vagrant"

  # The resource limit:
  # config.resource.set_limit(:CPU, 10 * 60)
  # config.resource.set_limit(:NOFILE, 30)

  # More examples and informations, please visit:
  # https://github.com/haconiwa/haconiwa/tree/master/sample
  # Enjoy your own container!
end
    RUBY

    CONFIG_TEMPLATE = <<-RUBY
Haconiwa.configure do |config|
end
    RUBY

    def self.generate_hacofile(hacofile, haconame=nil, root=nil)
      if File.exist?(hacofile)
        raise "hacofile already exists: #{hacofile}"
      end

      id = UUID.secure_uuid('%04x%04x')
      haconame ||= gen_haconame(id)
      root     ||= gen_root(id)

      template = BASE_TEMPLATE
      template = template.sub('!__NAME__!', haconame.inspect)
      template = template.sub('!__ROOT__!', root.inspect)

      File.open(hacofile, "w") do |f|
        f.puts template
      end
      puts 'create'.green + "\t#{hacofile}"
    end

    def self.generate_global_config
      if File.exist?("/etc/haconiwa.conf.rb")
        raise "Cannot override config file. Please run: rm -f /etc/haconiwa.conf.rb"
      end

      File.open("/etc/haconiwa.conf.rb", "w") do |f|
        f.puts CONFIG_TEMPLATE
      end
      puts 'create'.green + "\t/etc/haconiwa.conf.rb"
    end

    def self.gen_haconame(id)
      name = "haconiwa-#{id}"
      puts 'assign'.magenta + "\tnew haconiwa name = #{name}"
      name
    end

    def self.gen_root(id)
      loc = "/var/lib/haconiwa/#{id}"
      puts 'assign'.magenta + "\trootfs location = #{loc}"
      loc
    end
  end
end
