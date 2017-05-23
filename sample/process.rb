# A raw usage example of mrbgems to create your container

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
