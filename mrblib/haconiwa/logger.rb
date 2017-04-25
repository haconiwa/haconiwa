module Haconiwa
  module Logger
    extend self
    def setup(base)
      if Syslog.opened?
        Syslog.close
      end
      Syslog.open("haconiwa.#{base.name}")
    end

    # Calling this will stop haconiwa process
    def exception(*args)
      if args.first.is_a? HacoFatalError
        e = args.first
        Syslog.err("An exception is occurred when spawning haconiwa:")
        Syslog.err("#{e.inspect}")
        e.backtrace[1..-1].each{|l| Syslog.err "=> #{l}" } if e.backtrace
        Syslog.err("...Shutting down haconiwa")
        raise(e)
      elsif args.first.is_a? Exception
        e = args.first
        Syslog.err("#{e.inspect}")
        Syslog.err("=> #{e.backtrace.first}") if e.backtrace
        raise(HacoFatalError, e.inspect)
      else
        Syslog.err(*args)
        raise(HacoFatalError, *args)
      end
    end

    def err(*args)
      Syslog.err(*args)
    end

    # Warning is forced to be teed to stderr
    def warning(*args)
      Syslog.warning(*args)
      STDERR.puts(*args)
    end

    def notice(*args)
      Syslog.notice(*args)
    end

    def info(*args)
      Syslog.info(*args)
    end

    # Teeing log to stdout
    def puts(*args)
      Syslog.info(*args)
      Kernel.puts(*args)
    end

    def debug(*args)
      Syslog.debug(*args)
    end
  end
end
