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
    def err(*args)
      Syslog.err(*args)
      raise *args
    end

    # Warning is forced to be teed to stderr
    def warning(*args)
      Syslog.warning(*args)
      STDERR.puts *args
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
      Kernel.puts *args
    end

    def debug(*args)
      Syslog.debug(*args)
    end
  end
end
