module Haconiwa
  class Process
    def initialize
      if Haconiwa.config.etcd_available?
        @etcd = Etcd::Client.new(Haconiwa.config.etcd_url)
      else
        raise "`haconiwa ps' requires etcd available"
      end
    end

    LIST_FORMAT = "%-16s\t%-16s\t%-16s\t%-16s\t%-30s\t%-8s\t%5s\t%5s"

    def show_list
      puts sprintf(LIST_FORMAT, *(%w(NAME HOST ROOTFS COMMAND CREATED_AT STATUS PID SPID)))
      puts containers.map{|c| sprintf(LIST_FORMAT, *to_array(c)) }.join("\n")
    end

    def containers
      c = []
      hosts = @etcd.list("haconiwa.mruby.org")
      hosts.each do |host|
        if host["dir"]
          begin
            key = host["key"].sub(/^\//, '')
            @etcd.list(key).each do |container|
              c << JSON.parse(container["value"])
            end
          rescue
            STDERR.puts "[Warn] Invalid key #{key}. skip"
          end
        end
      end
      c
    end

    def to_array(json)
      [
        json["name"],
        json["etcd_name"],
        json["root"],
        json["command"],
        json["created_at"],
        json["status"],
        json["pid"],
        json["supervisor_pid"],
      ]
    end
  end
end
