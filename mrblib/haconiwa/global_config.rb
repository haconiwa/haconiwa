module Haconiwa
  class GlobalConfig
    attr_accessor :etcd_url

    def etcd_available?
      # WIP
    end

    class << self
      def instance
        @@__instance__ ||= new
      end
    end
  end

  class << self
    def config
      if block_given?
        yield ::Haconiwa::GlobalConfig.instance
      end
      ::Haconiwa::GlobalConfig.instance
    end
    alias configure config
  end
end
