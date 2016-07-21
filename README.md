# Haconiwa

[![Build Status](https://travis-ci.org/haconiwa/haconiwa.svg?branch=master)](https://travis-ci.org/haconiwa/haconiwa)

(m)Ruby on Container / helper tools with DSL for your handmade linux containers

## Install binary

Just download from [latest](https://github.com/haconiwa/haconiwa/releases):

```bash
VERSION=0.1.2
wget https://github.com/haconiwa/haconiwa/releases/download/v${VERSION}/haconiwa-v${VERSION}.x86_64-pc-linux-gnu.tgz
tar xzf haconiwa-v${VERSION}.x86_64-pc-linux-gnu.tgz
sudo install hacorb hacoirb haconiwa /usr/local/bin
haconiwa
# haconiwa - The MRuby on Container
# commands:
#     run       - run the container
#     attach    - attach to existing container
#     version   - show version
#     revisions - show mgem/mruby revisions which haconiwa bin uses
```

NOTE: If you'd like using cgroup-related features, install cgroup package such as `cgroup-lite` (Ubuntu) or `cgroup-bin` (Debian).
If you would not, these installation are not required.

## Example

Create the file `example.haco`:

```ruby
Haconiwa::Base.define do |config|
  config.name = "new-haconiwa001" # to be hostname

  config.cgroup["cpu.shares"] = 2048
  config.cgroup["memory.limit_in_bytes"] = "256M"
  config.cgroup["pid.max"] = 1024

  config.add_mount_point "/var/another/root/etc", to: "/var/your_rootfs/etc", readonly: true
  config.add_mount_point "/var/another/root/home", to: "/var/your_rootfs/home"
  config.mount_independent_procfs
  config.chroot_to "/var/your_rootfs"

  config.namespace.unshare "ipc"
  config.namespace.unshare "uts"
  config.namespace.unshare "mount"
  config.namespace.unshare "pid"

  config.capabilities.allow :all
  config.capabilities.drop "cap_sys_admin"
end
```

Then use `haconiwa` binary installed with thie gem.

```console
$ haconiwa run example.haco
```


When you want to attach existing container:

```console
$ haconiwa attach example.haco
```

Note: `attach` subcommand allows to set PID(`--target`) or container name(`--name`) for dynamic configuration.
And `attach` is not concerned with capabilities which is granted to container. So you can drop or allow specific caps with `--drop/--allow`.

### DSL spec

* `config.resource.set_limit` - Set the resource limit of container, using `setrlimit`
* `config.cgroup` - Assign cgroup parameters via `[]=`
* `config.namespace.unshare` - Unshare the namespaces like `"mount"`, `"ipc"` or `"pid"`
* `config.capabilities.allow` - Allow capabilities on container root. Setting parameters other than `:all` should make this acts as whitelist
* `config.capabilities.drop` - Drop capabilities of container root. Default to act as blacklist
* `config.add_mount_point` - Add the mount point odf container
* `config.mount_independent_procfs` - Mount the independent /proc directory in the container. Useful if `"pid"` is unshared
* `config.chroot_to` - The new chroot root
* `config.uid=/config.gid=` - The new container's running uid/gid. `groups=` is also respected
* `config.add_handler` - Define signal handler at supervisor process(not container itself). Available signals are `SIGTTIN/SIGTTOU/SIGUSR1/SIGUSR2`. See [handler example](./sample/cpu.haco).

You can pick your own parameters for your use case of container.
e.g. just using `mount` namespace unshared, container with common filesystem, limit the cgroups for big resource job and so on.

Please look into [`sample`](./sample) directory.

### Programming the container world by mruby

e.g.:

```ruby
Namespace.unshare(Namespace::CLONE_NEWNS)
Namespace.unshare(Namespace::CLONE_NEWPID)

m = Mount.new

m.make_private "/"
m.bind_mount "/var/lib/myroot", "/var/lib/haconiwa/root"

Dir.chroot "/var/lib/haconiwa"
Dir.chdir "/"

c = Process.fork {
  m.mount "proc", "/proc", :type => "proc"
  Exec.exec "/bin/sh"
}
pid, ret = Process.waitpid2 c
puts "Container exited with: #{ret.inspect}"
```

See dependent gem's READMEs.

## Development

* `rake compile` will create binaries.
* `rake` won't be passed unless you are not on Linux.
* This project is built upon great [mruby-cli](https://github.com/hone/mruby-cli). Please browse its README.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/haconiwa/haconiwa. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## TODOs

* [ ] Support setguid
* [ ] Support rlimits
* [ ] Haconiwa DSL compiler
* [ ] netns attachment
* [ ] More utilities such as `ps`
* [ ] Better daemon handling

## License

Under the GPL v3 License: See [LICENSE](./LICENSE) file.
