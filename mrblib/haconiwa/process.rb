module Haconiwa
  class ProcessList
    def initialize
      if Haconiwa.config.etcd_available?
        @etcd = Etcd::Client.new(Haconiwa.config.etcd_url)
      else
        raise "`haconiwa ps' requires etcd available"
      end
    end

    LIST_FORMAT = {
      "name" => 16,
      "etcd_name" => 16,
      "root" => 16,
      "command" => 16,
      "created_at" => 30,
      "status" => 8,
      "pid" => 5,
      "supervisor_pid" => 5,
    }

    def show
      rows = containers.map{|c| to_array(c) }
      fmt = make_format(rows)
      puts sprintf(fmt, *(%w(NAME HOST ROOTFS COMMAND CREATED_AT STATUS PID SPID)))
      unless rows.empty?
        puts rows.map{|r| sprintf(fmt, *r) }.join("\n")
      end
    end

    def containers
      c = []
      hosts = @etcd.list("haconiwa.mruby.org")
      hosts.each do |host|
        if host["dir"]
          begin
            key = host["key"].sub(/^\//, '')
            if cs = @etcd.list(key)
              cs.each do |container|
                c << JSON.parse(container["value"])
              end
            end
          rescue
            STDERR.puts "[Warn] Invalid key #{key}. skip"
          end
        end
      end
      c
    end

    def make_format(rows)
      lengths = []
      idx = 0
      LIST_FORMAT.each do |key, default_max|
        lengths << [default_max, *rows.map{|r| r[idx].to_s.length }].max
        idx += 1
      end
      sprintf "%%-%ds\t%%-%ds\t%%-%ds\t%%-%ds\t%%-%ds\t%%-%ds\t%%-%ds\t%%-%ds", *lengths
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
