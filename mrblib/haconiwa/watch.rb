module Haconiwa
  class Watch
    class Event
      def initialize(name, type, watch_key, hook)
        @name, @type, @watch_key, @hook = name, type, watch_key, hook
      end
      attr_reader :name, :type, :watch_key, :hook
    end

    class Cluster
      def self.instance
        @@__instance__ ||= new
      end

      def self.mutex
        @@__mutex__ ||= ::Mutex.new(global: true)
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
        case event["action"]
        when "create", "set"
          puts "Accept create event: #{event.inspect}"
          if v = (JSON.parse(node_info["value"]) rescue nil)
            @nodes[node_info["key"]] = v
          end
        when "delete"
          puts "Accept delete event: #{event.inspect}"
          @nodes.delete(node_info["key"])
        else
          puts "[Warn] Unknown event: #{event.inspect}"
        end
      end

      def count
        @nodes.keys.size
      end
    end

    class Response
      def initialize(resp, cluster)
        @raw_resp = resp
        @cluster  = Cluster.cluster
        @cluster.apply(resp)
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
    end

    def self.from_file(path)
      eval(File.read(path))
    end

    def self.run(watch)
      unless Haconiwa.config.etcd_available?
        raise "`haconiwa watch' requires etcd available"
      end
      p = UV::Prepare.new()

      asyncs = []
      watch.events.each do |name, event|
        a = UV::Async.new {|_|
          etcd = Etcd::Client.new(Haconiwa.config.etcd_url)
          cluster = nil
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
          loop do
            ret = etcd.wait(event.watch_key, true, wi_param)
            puts "Received: #{ret.inspect}"
            wi = ret["node"]["modifiedIndex"] rescue 0
            hook = UV::Async.new {|_|
              # TODO: race condition
              if event.hook
                Cluster.mutex.try_lock_loop do
                  self.lock
                end
                event.hook.call(Response.new(ret))
                Cluster.mutex.unlock
              end
            }
            hook.send
            wi_param = {wait_index: (wi + 1)}
          end
        }
        puts "Registered: #{event.name}"
        asyncs << a
      end

      p.start {|x|
        asyncs.each do |a|
          a.send
        end
      }

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
      puts "Spawn success".cyan + " #{cmdline}"
    else
      puts "[!]Spawn failed".red + " #{cmdline}"
      puts "[!]status code: #{status.inspect}"
    end
  end
end
