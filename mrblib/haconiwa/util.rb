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
  end
end
