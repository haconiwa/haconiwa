module Haconiwa
  class GlobalConfig
    attr_accessor :etcd_url

    def etcd_available?
      return false unless etcd_url

      _url = etcd_url.gsub("/v2", "").split(':')
      host = url[-2].gsub("/", "")
      port = url[-1].to_i
      !!(TCPSocket.open(host, port)) rescue false
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
