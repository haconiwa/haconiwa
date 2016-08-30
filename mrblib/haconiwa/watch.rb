module Haconiwa
  class Watch
    class Event
      def initialize(name, type, watch_key, hook)
        @name, @type, @watch_key, @hook = name, type, watch_key, hook
      end
      attr_reader :name, :type, :watch_key, :hook
    end

    class Cluster
      def self.cluster
        @@__instance__ ||= new
      end

      def initialize
        @nodes = {}
      end
      attr_reader :nodes

      def register(nodes_from_etcd)
        nodes_from_etcd.each do |node_info|
          if node_info["key"] and v = (JSON.parse(node_info["value"]) rescue nil)
            @nodes[node_info["key"]] = v
          end
        end
      end

      def apply(event)
        node_info = event["node"]
        key = node_info["key"]
        case action = event["action"]
        when "create", "set"
          if v = (JSON.parse(node_info["value"]) rescue nil)
            @nodes[key] = v
            puts "[Debug] Apply #{action} event for #{key}"
          end
        when "delete"
          @nodes.delete(key)
          puts "[Debug] Apply #{action} event for #{key}"
        else
          puts "[Warn] Unknown event: #{event.inspect}"
        end
      end

      def count
        @nodes.keys.size
      end
      alias size count
      alias length count
    end

    class Response
      def initialize(resp, cluster)
        @raw_resp = resp
        @cluster  = cluster
      end
      attr_reader :raw_resp, :cluster

      def created?
        @raw_resp["action"] == "create"
      end

      def set?
        @raw_resp["action"] == "set"
      end

      def deleted?
        @raw_resp["action"] == "delete"
      end

      def action
        @raw_resp["action"]
      end

      def changed_node
        @raw_resp["node"]
      end

      def prev_node
        @raw_resp["prevNode"]
      end

      def etcd_index
        @raw_resp["node"]["modifiedIndex"]
      end
    end

    def self.from_file(path)
      obj = eval(File.read(path))
      raise("Not a Watch DSL in file: #{path}") unless obj.is_a?(Watch)
      obj
    end

    def self.run(watch)
      unless Haconiwa.config.etcd_available?
        raise "`haconiwa watch' requires etcd available"
      end
      p = UV::Prepare.new()

      event = watch.events["cluster"]
      raise("No event registered") unless event

      etcd = Etcd::Client.new(Haconiwa.config.etcd_url)
      if event.type == :cluster
        cluster = Cluster.cluster
        hosts = etcd.list("haconiwa.mruby.org")
        hosts.each do |host|
          if host["dir"]
            begin
              key = host["key"].sub(/^\//, '')
              if info = etcd.list(key)
                cluster.register(info)
              end
            rescue
              STDERR.puts "[Warn] Invalid key #{key}. skip"
            end
          end
        end
      end

      wi = nil
      wi_param = {}
      p.start { |x|
        ret = etcd.wait(event.watch_key, true, wi_param)
        wi = ret["node"]["modifiedIndex"] rescue 0
        begin
          puts sprintf("Received: action=%s, node_key=%s, index=%d", ret["action"], ret["node"]["key"], wi)
        rescue
          puts "[Warn] Invalid response format: #{ret.inspect}".red
          retry
        end

        hook = UV::Async.new {|_|
          # race condition is resolved by UV::Async
          cluster = Cluster.cluster
          cluster.apply(ret)

          if event.hook
            # Cluster.mutex.try_lock_loop do
            #   self.lock
            # end
            event.hook.call(Response.new(ret, cluster))
            # Cluster.mutex.unlock
          end
        }
        hook.send
        wi_param = {wait_index: (wi + 1)}
      }

      puts "Registered: #{event.name}"
      UV::run()
    end

    def initialize(&b)
      @events = {}
      b.call(self) if block_given?
    end
    attr_accessor :events

    WATCH_KEYS = {
      :cluster => "haconiwa.mruby.org", # global event
    }

    def watch(event_type, &hook)
      watch_key = WATCH_KEYS[event_type]
      # TODO: another event types
      self.events["cluster"] = Event.new("cluster", event_type, watch_key, hook)
    end
  end

  def self.watch(&b)
    Watch.new(&b)
  end

  def self.spawn(hacofile)
    cmd = RunCmd.new("haconiwa.core.watch")
    cmdline = "haconiwa run #{hacofile}"
    p, status = cmd.run(cmdline)
    if status.success?
      puts "Spawn success:".green + " #{cmdline}"
    else
      puts "[!]Spawn failed:".red + " #{cmdline}"
      puts "[!]status code: #{status.inspect}"
    end
  end
end
