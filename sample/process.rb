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
