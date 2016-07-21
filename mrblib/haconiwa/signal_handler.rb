module Haconiwa
  class SignalHandler
    def initialize(base)
      @base = base
      @handlers = {}
    end

    def registered_signals
      @handlers.keys
    end

    def add_handler(sig, &b)
      if [:USR1, :USR2, :TTIN, :TTOU].include? sig.to_sym
        @handlers[sig.to_sym] = b
      else
        raise TypeError, "Unsupported signal: #{sig.inspect}"
      end
    end

    def register_handlers!
      base = @base
      @handlers.each do |sig, handler|
        ::Signal.trap(sig) do |signo|
          handler.call(base, signo)
        end
      end
    end
  end
end
