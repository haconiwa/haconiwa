# This is future use, maybe...
module Haconiwa
  class GlobalConfig
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
