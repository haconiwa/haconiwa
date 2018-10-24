module Haconiwa
  def self.current_subcommand=(sub)
    @@current_subcommand = sub
  end

  def self.current_subcommand
    @@current_subcommand
  end

  module Util
    extend self
    def to_safe_shellargs(args)
      args.map {|a|
        if a.empty? or a =~ /^\s+$/
          ""
        else
          Shellwords.escape(a)
        end
      }
    end

    def safe_shell_fmt(fmt, *args)
      sprintf(fmt, *to_safe_shellargs(args))
    end

    def ppid_to_pid(ppid)
      status = `find /proc -maxdepth 2 -regextype posix-basic -regex '/proc/[0-9]\\+/status'`.
               split.
               find {|f| ::File.read(f).include? "PPid:\t#{ppid}\n" rescue false }
      raise(HacoFatalError, "Container PID not found by find") unless status
      status.split('/')[2].to_i
    end

    def do_get_base(hacofile)
      script = File.read(hacofile)
      obj = Kernel.eval(script)
      obj.hacofile = (hacofile[0] == '/') ? hacofile : ExpandPath.expand(hacofile, Dir.pwd)
      return obj
    end

    def get_base(args)
      do_get_base(args[0])
    end

    def get_script_and_eval(args)
      hacofile = args[0]
      exe = args[1..-1]
      if exe.first == "--"
        exe.shift
      end
      obj = do_get_base(hacofile)

      return [obj, exe]
    end
  end
end
