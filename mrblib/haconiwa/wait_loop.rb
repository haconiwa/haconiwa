module Haconiwa
  class WaitLoop
    def initialize
      @sig_threads = []
      @hook_threads = []
      @registered_hooks = []
    end

    def register_hooks(base)
      base.async_hooks.each do |hook|
        hook.set_signal!
        proc = hook.proc
        @hook_threads << SignalThread.trap(hook.signal) do
          ::Haconiwa::Logger.warning("Async hook starting...")
          begin
            case proc.arity
            when 1
              proc.call(base)
            when 2
              proc.call(base, hook.active_timer)
            else
            end
          rescue => e
            ::Haconiwa::Logger.warning("Async hook failed: #{e.class}, #{e.message}")
          end
        end
        @registered_hooks << hook
      end
    end

    def register_sighandlers(base, runner)
      # Registers cleanup handler when unintended death
      [:SIGTERM, :SIGINT, :SIGPIPE].each do |sig|
        @sig_threads << SignalThread.trap_once(sig) do
          unless base.cleaned
            Logger.warning "Supervisor received unintended kill. Cleanup..."
            runner.cleanup_supervisor(base)
          end
          Process.kill :TERM, base.pid
          exit 127
        end
      end

      if base.daemon? # Terminal uses SIGHUP
        # Registers reload handler
        b1 = base.cgroup(:v1).defblock
        b2 = base.cgroup(:v2).defblock

        @sig_threads << SignalThread.trap(:SIGHUP) do
          begin
            newcg = Haconiwa::CGroup.new
            Haconiwa::Logger.info "Accepted reload: PID=#{base.pid}"
            b1.call(newcg) if b1
            newcg2 = Haconiwa::CGroupV2.new
            b2.call(newcg2) if b2
            base.reload(newcg, newcg2)
          rescue Exception => e
            Haconiwa::Logger.warning "Reload failed: #{e.class}, #{e.message}"
            e.backtrace.each{|l| Haconiwa::Logger.warning "    #{l}" }
          end
        end
      end
    end

    def register_custom_sighandlers(base, handlers)
      handlers.each do |sig, callback|
        @sig_threads << SignalThread.trap(sig) do |signo|
          callback.call(base)
        end
      end
    end

    def run_and_wait(pid)
      @registered_hooks.each do |hook|
        hook.start
      end
      p, s = Process.waitpid2(pid)
      Logger.puts "Container(#{p}) finish detected: #{s.inspect}"
      return [p, s]
    end

    class TimerHook
      def self.signal_pool
        @__signal_pool = []
      end

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
        @interval = timing[:interval_msec] # TODO: other time scales
        @proc = b
        @id = UUID.secure_uuid
        @signal = nil
        @active_timer = nil
      end
      attr_reader :timing, :proc, :id, :signal, :active_timer

      # This method has a race problem, should be called serially
      def set_signal!
        idx = 0
        while !signal do
          if TimerHook.signal_pool.include?(:"SIGRT#{idx}")
            idx += 1
          else
            @signal = :"SIGRT#{idx}"
            TimerHook.signal_pool << @signal
          end
        end
      end

      def start
        if signal
          t = ::Timer::POSIX.new(signal: signal)
          if @interval
            t.run(@timing, @interval)
          else
            t.run(@timing)
          end
          Logger.info("Timer registered: #{t.inspect}")
          @active_timer = t
        end
      end
    end
  end
end
