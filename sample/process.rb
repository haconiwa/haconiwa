Namespace.unshare(Namespace::CLONE_NEWNS)

system "mount --make-private /"
system "mount --bind /var/lib/myroot /var/lib/haconiwa/root"

Namespace.unshare(Namespace::CLONE_NEWPID)
c = Process.fork { Exec.exec "/bin/sh", "-c", "chroot /var/lib/haconiwa /bin/bash -c 'mount -t proc proc /proc; exec /bin/sh'" }
Process.waitpid c
