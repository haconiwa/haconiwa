module Haconiwa
  module Logger
    DEBUG   = 0
    NOTICE  = 1
    INFO    = 2
    WARNING = 3
    ERROR   = 4

    extend self
    def setup(base)
      if Syslog.opened?
        Syslog.close
      end
      Syslog.open("haconiwa.#{base.name}")
      @log_level = base.log_level
    end

    # Calling this will stop haconiwa process
    def exception(*args)
      if args.first.is_a? HacoFatalError
        e = args.first
        err("An exception is occurred when spawning haconiwa:")
        err("#{e.inspect}")
        e.backtrace[1..-1].each{|l| err "=> #{l}" } if e.backtrace
        err("...Shutting down haconiwa")
        raise(e)
      elsif args.first.is_a? Exception
        e = args.first
        err("#{e.inspect}")
        err("=> #{e.backtrace.first}") if e.backtrace
        raise(HacoFatalError, e.inspect)
      else
        err(*args)
        raise(HacoFatalError, *args)
      end
    end

    def err(*args)
      Syslog.err(*args) if @log_level <= ERROR
    end

    # Warning is forced to be teed to stderr
    def warning(*args)
      Syslog.warning(*args) if @log_level <= WARNING
      STDERR.puts(*args)
    end

    def notice(*args)
      Syslog.notice(*args) if @log_level <= NOTICE
    end

    def info(*args)
      Syslog.info(*args) if @log_level <= INFO
    end

    # Teeing log to stdout
    def puts(*args)
      info(*args)
      Kernel.puts(*args)
    end

    def debug(*args)
      Syslog.debug(*args) if @log_level <= DEBUG
    end
  end
end
