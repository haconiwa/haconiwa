module Haconiwa
  module Logger
    DEBUG   = 0
    NOTICE  = 1
    INFO    = 2
    WARNING = 3
    ERROR   = 4

    class << self
      def instance
        @instance ||= SyslogLogger.new
      end

      def set_default_instance!(logger)
        old = @instance
        @instance = logger
        return old
      end

      %w(setup exception err warning notice info puts debug).each do |meth|
        define_method(meth) do |*arg|
          instance.__send__(meth, *arg)
        end
      end
    end

    class SyslogLogger
      def initialize
        if Syslog.opened?
          Syslog.close
        end
        Syslog.open("haconiwa")
        @log_level = INFO
      end

      def setup(base)
        _setup(base.name, base.log_level)
      end

      def _setup(name, level)
        if Syslog.opened?
          Syslog.close
        end
        Syslog.open("haconiwa.#{name}")
        @log_level = [level, ERROR].min
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
          if e.backtrace
            e.backtrace[0..2].each do |bt|
              err("=> #{bt}")
            end
          end
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
end
