module Haconiwa
  class WaitLoop
    def initialize
      @hooks = []
    end
    attr_reader :hooks

    def register_hooks(base)
      timers = []
      @hooks.each do |hook|
        t = UV::Timer.new
        hook.register(t, base)
        timers << t
      end
      timers
    end

    def register_sighandlers(base, runner, etcd)
      sigs = []
      [:SIGTERM, :SIGINT, :SIGHUP, :SIGPIPE].each do |sig|
        s = UV::Signal.new()
        s.start(UV::Signal.const_get(sig)) do |signo|
          unless base.cleaned
            Logger.warning "Supervisor received unintended kill. Cleanup..."
            runner.cleanup_supervisor(base, etcd)
          end
          UV::default_loop.stop()
          exit 127
        end
      end
    end

    def run_and_wait(pid)
      main = UV::Timer.new
      p = s = nil
      main.start(100, 100) do
        p, s = Process.waitpid2(pid, Process::WNOHANG)
        if p
          Logger.puts "Container(#{p}) finish detected: #{s.inspect}"
          UV::default_loop.stop()
        end
      end
      UV::run()
      return [p, s]
    end

    class TimerHook
      def initialize(timing={}, &b)
        @timing = if s = timing[:msec]
                    s
                  elsif s = timing[:sec]
                    s * 1000
                  elsif s = timing[:min]
                    s * 1000 * 60
                  elsif s = timing[:hour]
                    s * 1000 * 60 * 60
                  else
                    raise(ArgumentError, "Invalid option: #{timing.inspect}")
                  end
        @proc = b
        @id = SecureRandom.secure_uuid
      end
      attr_reader :timing, :proc, :id

      def register(t, base)
        t.start(@timing, 0) do
          Logger.debug "The timer hook(#{@id}) invoked after #{@timing} msec"
          @proc.call(base)
          Logger.debug "The timer hook(#{@id}) success"
        end
      end
    end
  end
end
