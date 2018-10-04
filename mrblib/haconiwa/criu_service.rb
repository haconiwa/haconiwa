module Haconiwa
  class CRIUService
    include Hookable

    def initialize(base)
      @base = base
    end

    def checkpoint
      @base.checkpoint
    end

    def create_checkpoint
      syscall = checkpoint.target_syscall
      if syscall.nil? || syscall.empty?
        Haconiwa::Logger.exception "Target systemcall not specified. Abort"
      end

      c = CRIU.new
      c.set_images_dir checkpoint.images_dir
      c.set_service_address checkpoint.criu_service_address
      c.set_log_file checkpoint.criu_log_file
      c.set_shell_job true

      pid = Process.fork do
        context = ::Seccomp.new(default: :allow) do |rule|
          rule.trace(*syscall)
        end
        context.load

        Dir.chdir ExpandPath.expand([@base.filesystem.chroot, @base.workdir].join('/'))
        Dir.chroot @base.filesystem.chroot
        Exec.execve(@base.environ, *@base.init_command)
      end

      ret = ::Seccomp.start_trace(pid) do |syscall, _pid, ud|
        name = ::Seccomp.syscall_to_name(syscall)
        Haconiwa::Logger.puts "CRIU: syscall #{name}(##{syscall}) called. (ud: #{ud}), dump the process image."

        begin
          c.set_pid _pid
          c.dump
        rescue => e
          Haconiwa::Logger.puts "CRIU: dump failed: #{e.class}, #{e.message}"
        else
          Haconiwa::Logger.puts "CRIU: dumped!!"
        end
      end
    end

    class RestoreCMD
      def initialize(bin_path)
        @bin_path = bin_path
        @options = []
        @externals = []
        @cg_roots = []
        @run_exec_cmd = true
        @exec_cmd = nil
      end
      attr_accessor :options, :externals, :cg_roots, :exec_cmd

      def to_execve_arg
        [
          @bin_path,
          "restore"
        ] + rest_arguments
      end
      alias inspect to_execve_arg

      def rest_arguments
        a = @options.dup
        @externals.each do |opt|
          a.concat(["--external", opt])
        end
        @cg_roots.each do |root|
          a.concat(["--cgroup-root", root])
        end
        if @exec_cmd
          a.concat(["--exec-cmd", "--"])
          a.concat(@exec_cmd.dup)
        end
        a
      end
    end

    def restore
      # TODO: embed criu(crtools) to haconiwa...
      # Hooks won't work
      pidfile = "/tmp/.__criu_restored_#{@base.name}.pid"
      cmds = RestoreCMD.new(checkpoint.criu_bin_path)
      cmds.options << "--shell-job"
      cmds.options.concat ["--pidfile", pidfile] # FIXME: shouldn't criu cli pass its pid via envvar?
      cmds.options.concat ["-D",checkpoint.images_dir]
      self_exe = File.readlink "/proc/self/exe"

      nw = @base.network
      if nw.enabled?
        external_string = "veth[#{nw.veth_guest}]:#{nw.veth_host}@#{nw.bridge_name}"
        cmds.externals << external_string

        ENV['HACONIWA_NEW_IP'] = nw.container_ip_with_netmask
        ENV['HACONIWA_RUN_AS_CRIU_ACTION_SCRIPT'] = "true"
      end

      unless @base.filesystem.mount_points.empty?
        cmds.externals << "mnt[]:"
        @base.filesystem.external_mount_points.each do |mp|
          cmds.externals << "mnt[#{mp.criu_ext_key}]:#{mp.src}"
        end
      end

      @base.cgroup.controllers_in_real_dirname.each do |dir|
        cmds.cg_roots << "#{dir}:/#{@base.name}"
      end

      # Order of external...
      # FIXME make this command generator a class
      if nw.enabled?
        cmds.options.concat(["--action-script", self_exe])
      end

      cmds.options.concat(["--root", @base.filesystem.root_path])

      unless checkpoint.extra_criu_options.empty?
        cmds.options.concat(checkpoint.extra_criu_options)
      end
      checkpoint.extra_criu_externals.each do |extra|
        cmds.externals << extra
      end

      cmds.exec_cmd = [self_exe, "_restored", @base.hacofile, pidfile]

      invoke_general_hook(:before_restore, @base)
      Haconiwa::Logger.debug("Going to exec: #{cmds.inspect}")
      ::Exec.execve(ENV, *cmds.to_execve_arg)
    end
  end
end
