module Haconiwa
  class WaitLoop
    def initialize
      @hooks = []
    end
    attr_reader :hooks

    def run
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
      end
      attr_reader :timing, :proc
    end
  end
end
