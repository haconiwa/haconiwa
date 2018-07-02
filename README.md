# Haconiwa

<img src="images/haconiwa-logo.png" alt="The logo" width="500" />

mRuby on Container / helper tools with DSL for your handmade linux containers. [![Build Status](https://travis-ci.org/haconiwa/haconiwa.svg?branch=master)](https://travis-ci.org/haconiwa/haconiwa)

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

Available for: `CentOS >= 7 / CentOS ~> 6(Experimental, maybe kernel update required) / Fedora >= 23 / Ubuntu Trusty / Ubuntu Xenial / Debian jessie` (which are supported by best effort...)

(PR: We are welcoming package maintainers for other distro!!!)

Other linuxes users can just download binaries from [latest](https://github.com/haconiwa/haconiwa/releases):

```bash
VERSION=<specify version>
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

Create mount points:

```sh
$ mkdir -p /var/another/root/etc
$ mkdir -p /var/another/root/home
```

Create the file `example.haco`:

```ruby
Haconiwa::Base do |config|
  config.name = "new-haconiwa001" # to be hostname

  config.bootstrap do |b|
    b.strategy = "lxc"
    b.os_type = "centos"
  end

  config.provision do |p|
    p.run_shell "yum -y install git"
  end

  config.cgroup["cpu.shares"] = 2048
  config.cgroup["memory.limit_in_bytes"] = 256 * 1024 * 1024
  config.cgroup["pids.max"] = 1024

  config.add_mount_point "/var/another/root/etc", to: "/var/your_rootfs/etc", readonly: true
  config.add_mount_point "/var/another/root/home", to: "/var/your_rootfs/home"
  config.mount_independent "procfs"
  config.mount_independent "sysfs"
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

`config.bootstrap` block support 6 strategies now.

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
* `strategy = "git"`
  * needs `git` command :)
  * `git.git_url` to set the repository URL for clone
  * `git.git_options` to set extra `git` options by Array, if necessary
* `strategy = "tarball"`
  * needs `tar` command ;)
  * `tb.archive_path` to set the source archive path on your host machine
  * `tb.tar_options` to set extra `tar` options by Array, if necessary
* `strategy = "shell" / "mruby"`
  * `shell.code` to set a shell or mruby code by string(heredoc is OK). You can pass the mruby code block for `"mruby"`

#### Provision

`config.provision` block support some operations(in the future. now `run_shell` only).

* `run_shell` to set plane shell script(automatically `set -xe`-ed on run)
  * We can declare `run_shell` multiple times
  * Set name by `name:` option, then you can specify provision operation by `haconiwa provision --run-only=...`

#### Running container environment

* `config.environ` - A hash to pass environment variables to a created container. e.g. `config.environ = {"FOO_KEY" => "value", ...}`
* `config.workdir` - The working directory of haconiwa's init command
* `config.command.set_stdout/set_stderr` - Emit command's stdout/err to specified files. This is active only on daemon mode
* `config.resource.set_limit` - Set the resource limit of container, using `setrlimit`
* `config.cgroup` - Assign cgroup parameters via `[]=`
* `config.namespace.unshare` - Unshare the namespaces like `"mount"`, `"ipc"` or `"pid" ...`. `persist_in` option make the specified namespace persist in a bind-moounted-file
  * See: http://karelzak.blogspot.jp/2015/04/persistent-namespaces.html
* `config.network` - Specify networking config. `Network#namespace` and `#container_ip` must be set. Other attributes are `#bridge_name`, `#bridge_ip`, `#veth_host`, `#veth_guest`
* `config.capabilities.reset_to_privileged!` - Haconiwa has default capability whitelist to use. If you want to use customized black/whitelist, declare this first
* `config.capabilities.allow` - Allow capabilities on container root. Setting parameters other than `:all` should make this acts as whitelist
* `config.capabilities.drop` - Drop capabilities of container root. Default to act as blacklist
* `config.add_mount_point` - Add the mount point of container. Source directory is resolved from the directory where a user run haconiwa
* `config.mount_independent` - Mount the independent filesystems: `"procfs", "sysfs", "devtmpfs", "devpts" and "shm"` in the newborn container. Useful if `"pid"` or `"net"` are unshared
* `config.chroot_to` - The new chroot root
* `config.uid=/config.gid=` - The new container's running uid/gid. `groups=` is also respected
* `config.support_reload` - Specify reloadable parameters when invoked `haconiwa reload` command. Only `:cgroup` and `:resource` are available for now and it is active only when they are defined following configuration blocks. See test cases and examples
* `config.wait_interval` - Specify the sleep interval in `wait` and `watchdog` loops by milli seconds
* `config.metadata` - Add container's metadata(tagging) by ruby Hash
* `config.lxcfs_root` - Set your host's `lxcfs` mount point to cooperate with containers

You can pick your own parameters for your use case of container.
e.g. just using `mount` namespace unshared, container with common filesystem, limit the cgroups for big resource job and so on.

#### Hooks

* `config.add_general_hook(hookpoint, &block)` - Define hook codes that are invoked through the Haconiwa's spawning process. Hook points are below:
  * `:before_fork` - Hooked just before the container process is forked
  * `:after_fork` - Hooked just after the container process is forked, in forked process
  * `:before_chroot` - Hooked just after container settins are applied (e.g. namespace, cgroup, caps, fs mounting) and just before do chroot in forked process
  * `:after_chroot` - Hooked just after the chroot is successful, in forked process. This is the last timing before doing `exec()` and becoming a new program
  * `:before_start_wait` - Hooked before starting to `wait()` the container process. Hook itself is invoked in the parent process
  * `:teardown_container` - Hooked after the container process has quitted, in the parent process. `base.exit_status` is set
  * `:after_reload` - Hooked just after `haconiwa reload` is invoked and successful
  * `:after_failure` - Hooked just after tha container process is exited with failure. `base.exit_status` is set
  * Every hook can accept one argument `base`, which is Haconiwa::Base object.
* hooks below are system hooks, which are invoked in across-supervisor layer.
  * `:setup` - Hooked just before the supervisor processes are going to be forked
  * `:teardown` - Hooked after the supervisor processes have quitted all
  * `:system_failure` - Hooked just after tha container process is exited with failure
    * Either `barn.exit_status` or `barn.system_exception` will be available
  * Every hook can accept one argument `barn`, which is Haconiwa::Barn object.
* `config.add_async_hook(option, &block)` - Define timer handler. Supported options:
  * `:msec/:sec/:min/:hour` - First timeout to invoke hook.
  * `:interval_msec` - Define the interval timeout hooks, if this paramete exists.
  * NOTE: Async hook uses POSIX timer and real-time signals internally. Please do not queue real-time signals directly.
* `config.add_signal_handler(signame, &block)` - Define signal handler at supervisor process(not container itself). Available signals are `SIGTTIN/SIGTTOU/SIGUSR1/SIGUSR2`. See [handler example](./sample/cpu.haco).
* `config.validate_real_id(&block{|ruid, rgid| ... })` - Validates the Real UID/GID who invoked haconiwa command. return true if OK, false/nil to mark invalid. This is useful when haconiwa command is set-user-ID root

Please check out [`sample`](./sample) directory.

### Programming the container world by mruby

e.g.:

```ruby
Namespace.unshare(Namespace::CLONE_NEWNS)
Namespace.unshare(Namespace::CLONE_NEWPID)

Mount.make_private "/"
Mount.bind_mount "/var/lib/myroot", "/var/lib/haconiwa/root"

Dir.chroot "/var/lib/haconiwa"
Dir.chdir "/"

c = Process.fork {
  Mount.mount "proc", "/proc", :type => "proc"
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

## Release policy

* Versions whose minor versions are *even* numbers (`0.6, 0.8, 0.10, 1.0...`): Stable release
* Versions whose minor versions are *odd* numbers (`0.7, 0.9, 0.11, 1.1...`): Unstable release. Features added at this version should be broken
* I introduced this policy after version `0.5.x`
* We create branches as `0.6.x-dev` for release
* PRs can be proposed to `master` branch. Maintainers will pick these to stable/unstable dev branches

## TODOs

* [ ] Haconiwa DSL compiler
* [ ] Networking helpers
* [ ] P2P containers

## License

Haconiwa core is under the GPL v3 License: See [LICENSE](./LICENSE) file.

Haconinwa's logo is originally created by [@takeshige](https://github.com/takeshige), and is under [Creative Commons License **BY-NC-ND** 4.0](https://creativecommons.org/licenses/by-nc-nd/4.0/). ![CC BY-NC-ND](https://licensebuttons.net/l/by-nc-nd/4.0/88x31.png)

Bundled libraries (libcap, libcgroup, libargtable and mruby) are licensed by each authors. See `LICENSE_*` file.

For other mgems' licenses, especially ones which are not bundled by mruby-core, please refer their `github.com` repository.
