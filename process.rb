f = Process.fork do
  Namespace.unshare(Namespace::CLONE_NEWNS)
  # Namespace::CLONE_NEWPID

  system "mount --make-private /"
  system "mount --bind /var/lib/myroot /var/lib/haconiwa/root"

  Namespace.unshare(Namespace::CLONE_NEWPID)
  g = Process.fork { Exec.exec "/bin/sh", "-c", "chroot /var/lib/haconiwa /bin/bash -c 'mount -t proc proc /proc; exec /bin/sh'" }
  Process.waitpid g
end
Process.waitpid f
