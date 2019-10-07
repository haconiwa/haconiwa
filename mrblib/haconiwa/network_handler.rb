module Haconiwa
  class NetworkHandler
    class Bridge
      def initialize(network)
        @network = network
        if !network.namespace || !network.container_ip
          raise ArgumentError, "Required network config(s) are missing: #{network.inspect}"
        end
      end
      attr_reader :network

      def to_ns_file
        "/var/run/netns/#{network.namespace}"
      end
      alias ns_file to_ns_file

      def generate
        # TODO: defaulting to too verbose, this should be configurable
        setup_cmd_logger

        make_network_namespace
        make_veth
        make_container_network
      rescue => e
        @failed = true
        raise(e)
      ensure
        cleanup if @failed
        teardown_cmd_logger
      end

      def cleanup
        return unless File.exist?(ns_file)

        unless system("ip netns del #{network.namespace}")
          raise "Cleanup of namespace failed"
        end
        system "ip link del #{network.veth_host} || true"
      end

      private
      def make_network_namespace
        return if File.exist?(ns_file)
        unless safe_ip_run("ip netns add %s", network.namespace)
          raise "Creating namespace failed: ip netns add #{network.namespace}"
        end
      end

      def make_veth
        [
          "ip link add #{network.veth_host} type veth peer name #{network.veth_guest}",
          "ip link set #{network.veth_host} up",
          "ip link set dev #{network.veth_host} master #{network.bridge_name}"
        ].each do |cmd|
          unless safe_ip_run(cmd)
            raise "Creating veth failed: #{cmd}"
          end
        end
      end

      def make_container_network
        ns = network.namespace
        [
          "ip link set #{network.veth_guest} netns #{ns} up",
          "ip netns exec #{ns} ip addr add #{network.container_ip}/#{network.netmask} dev #{network.veth_guest}",
          "ip netns exec #{ns} ip link set lo up",
          "ip netns exec #{ns} ip route add default via #{network.bridge_ip}"
        ].each do |cmd|
          unless safe_ip_run(cmd)
            raise "Creating container networks failed: #{cmd}"
          end
        end
      end

      def setup_cmd_logger
        fifo_root = ENV['HACONIWA_TMP_LOG_DIR'] || ENV['TMPDIR'] || '/tmp'
        @fifo_path = Util.safe_shell_fmt("#{fifo_root}/#{network.namespace}-#{Process.pid}-#{UUID.secure_uuid[0..7]}.fifo")
        Haconiwa.mkfifo(@fifo_path, 0600)
        @drain = Process.fork do
          d = File.open(@fifo_path, 'r')
          loop do
            lines = d.readlines
            lines.each do |l|
              Haconiwa::Logger.warning("[NetworkHandler] #{l.chomp}")
            end
          end
        end
      end

      def safe_ip_run(*args)
        raise("FIFO logging not set") unless @fifo_path
        cmd_safe = Util.safe_shell_fmt(*args)
        system "( echo Running #{cmd_safe}; #{cmd_safe} ) > #{@fifo_path} 2>&1"
      end

      def teardown_cmd_logger
        Process.kill :TERM, @drain
        Process.waitpid @drain
      ensure
        system Util.safe_shell_fmt("rm -f %s", @fifo_path)
      end

      def self.generate_bridge(bridge_name, bridge_ip_netmask)
        unless bridge_ip_netmask =~ /\/\d+$/
          bridge_ip_netmask << '/24'
        end
        runner = RunCmd.new("init.network.bridge")
        [
          "ip link add #{bridge_name} type bridge",
          "ip addr add #{bridge_ip_netmask} dev #{bridge_name}",
          "ip link set dev #{bridge_name} up"
        ].each do |cmd|
          _, status = runner.run(cmd)
          if !status.success?
            raise "Creating container networks failed: #{cmd}"
          end
        end
      end
    end
  end
end
