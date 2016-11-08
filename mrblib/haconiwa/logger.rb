module Haconiwa
  module Logger
    def self.setup(base)
      if Syslog.opened?
        Syslog.close
      end
      Syslog.open("haconiwa.#{base.name}")
    end

    def err(*args)
      Syslog.err(*args)
    end

    def warning(*args)
      Syslog.warning(*args)
    end

    def notice(*args)
      Syslog.notice(*args)
    end

    def info(*args)
      Syslog.info(*args)
    end

    def debug(*args)
      Syslog.debug(*args)
    end
  end
end
