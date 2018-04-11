module Haconiwa
  class WaitLoop
    def initialize(wait_interval=50)
      @mainloop = FiberedWorker::MainLoop.new
      @wait_interval = wait_interval
    end
    attr_accessor :mainloop, :wait_interval

    def register_hooks(base)
      base.async_hooks.each do |hook|
        hook.set_signal!
        proc = hook.proc
        @mainloop.register_timer(hook.signal, hook.timing, hook.interval) do
          ::Haconiwa::Logger.warning("Async hook starting...")
          begin
            proc.call(base)
          rescue => e
            ::Haconiwa::Logger.warning("Async hook failed: #{e.class}, #{e.message}")
          end
        end
      end
    end

    def register_sighandlers(base, runner)
      # Registers cleanup handler when unintended death
      [:SIGTERM, :SIGINT, :SIGPIPE].each do |sig|
        @mainloop.register_handler(sig, true) do
          unless base.cleaned
            ::Haconiwa::Logger.warning "Supervisor received unintended kill. Cleanup..."
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
        r1 = base.resource.defblock

        @mainloop.register_handler(sig, false) do
          begin
            newcg = Haconiwa::CGroup.new
            Haconiwa::Logger.info "Accepted reload: PID=#{base.pid}"
            b1.call(newcg) if b1
            newcg2 = Haconiwa::CGroupV2.new
            b2.call(newcg2) if b2
            newres = Haconiwa::Resource.new
            r1.call(newres) if r1

            base.reload(newcg, newcg2, newres)
          rescue Exception => e
            Haconiwa::Logger.warning "Reload failed: #{e.class}, #{e.message}"
            e.backtrace.each{|l| Haconiwa::Logger.warning "    #{l}" }
          end
        end
      end
    end

    def register_custom_sighandlers(base, handlers)
      handlers.each do |sig, callback|
        @mainloop.register_handler(sig, false) do
          callback.call(base)
        end
      end
    end

    def run_and_wait(pid)
      @mainloop.pid = pid
      p, s = *(@mainloop.run)
      Haconiwa::Logger.puts "Container[Host PID=#{p}] finished: #{s.inspect}"
      return [p, s]
    end

    class TimerHook
      def self.signal_pool
        @__signal_pool ||= []
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
        @interval = timing[:interval_msec] || 0 # TODO: other time scales
        @proc = b
        @id = UUID.secure_uuid
        @signal = nil
      end
      attr_reader :timing, :interval, :proc, :id, :signal

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
    end
  end
end
