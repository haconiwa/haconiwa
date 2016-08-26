module Haconiwa
  class Watch
    def self.run
      unless Haconiwa.config.etcd_available?
        raise "`haconiwa watch' requires etcd available"
      end
      p = UV::Prepare.new()

      a = UV::Async.new {|_|
        etcd = Etcd::Client.new(Haconiwa.config.etcd_url)
        loop do
          ret = etcd.wait("haconiwa.mruby.org", true)
          puts "Changed: #{ret.inspect}"
        end
      }

      p.start {|x|
        a.send
      }

      UV::run()
    end
  end
end
