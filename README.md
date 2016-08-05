# Haconiwa

[![Build Status](https://travis-ci.org/haconiwa/haconiwa.svg?branch=master)](https://travis-ci.org/haconiwa/haconiwa)

mRuby on Container / helper tools with DSL for your handmade linux containers.

Haconiwa (`箱庭` - a miniature garden) is a container builder DSL, by which you can choose any container-related technologies as you like:

- Linux namespace
- Linux control group(cgroup)
- Linux capabilities
- Bind mount / chroot
- Resource limit(rlimit)
- setuid/setgid
- ...

Haconiwa is written in [mruby](https://mruby.org/), so you can utilize Ruby DSL for creating your own container.

## Install binary

`haconiwa` packages are provided via [packagecloud](https://packagecloud.io/udzura/haconiwa).

Available for: `CentOS >= 7 / Ubuntu Trusty / Ubuntu Xenial / Debian jessie` (which are supported by best effort...)

Other linuxes users can just download binaries from [latest](https://github.com/haconiwa/haconiwa/releases):

```bash
VERSION=0.2.2
wget https://github.com/haconiwa/haconiwa/releases/download/v${VERSION}/haconiwa-v${VERSION}.x86_64-pc-linux-gnu.tgz
tar xzf haconiwa-v${VERSION}.x86_64-pc-linux-gnu.tgz
sudo install hacorb hacoirb haconiwa /usr/local/bin
haconiwa
# haconiwa - The MRuby on Container
# commands:
#     run       - run the container
#     attach    - attach to existing container
#     ...
```

NOTE: If you'd like using cgroup-related features, install cgroup package such as `cgroup-lite` (Ubuntu) or `cgroup-bin` (Debian).
If you would not, these installation are not required.

## Example

### Bootstraping container filesystem

Create the file `example.haco`:

```ruby
Haconiwa::Base.define do |config|
  config.name = "new-haconiwa001" # to be hostname

  config.bootstrap do |b|
    b.strategy = "lxc"
    b.os_type = centos
  end

  config.provision do |p|
    p.run_shell "yum -y install git"
  end

  config.cgroup["cpu.shares"] = 2048
  config.cgroup["memory.limit_in_bytes"] = 256 * 1024 * 1024
  config.cgroup["pids.max"] = 1024

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

Then run the `haconiwa create` command to set up container base root filesystem.

```console
$ haconiwa create example.haco
Start bootstrapping rootfs with lxc-create...
...
```

To re-run provisioning, you can use `haconiwa provision`.

### Running

Then use `haconiwa run` command to make container up.

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

#### Bootstrap

`config.bootstrap` block support 2 strategy.

* `strategy = "lxc"`
  * needs `lxc-create` command
  * `lxc.project_name` to set PJ name. default to the dirname
  * `lxc.os_type` to set OS type installed to
* `strategy = "debootstrap"`
  * needs `debootstrap` command
  * `deb.variant` to set Debian variant param to pass debootstrap
  * `deb.debian_release` to set Debian's release name squeeze/jessie/sid and so on...
  * `deb.mirror_url` to set mirror URL debootstrap uses
  * `deb.components` to set components installed. eg, `'base'`

#### Provision

`config.provision` block support some operations(in the future. now `run_shell` only).

* `run_shell` to set plane shell script(automatically `set -xe`-ed on run)
  * We can declare `run_shell` multiple times
  * Set name by `name:` option, then you can specify provision operation by `haconiwa provision --run-only=...`

#### Running environment

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

Haconiwa core is under the GPL v3 License: See [LICENSE](./LICENSE) file.

Bundled libraries (libcap, libcgroup, libargtable and mruby) are licensed by each authors. See `LICENSE_*` file.

For other mgems' licenses, especially ones which are not bundled by mruby-core, please refer their `github.com` repository.
