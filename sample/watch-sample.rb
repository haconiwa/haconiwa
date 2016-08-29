Haconiwa.watch do |config|
  config.watch :cluster do |event|
    # puts "Receive!" + event.raw_resp.inspect
    # puts "Receive!" + event.cluster.inspect
    if event.cluster.count <= 5
      (5 - event.cluster.count).times do
        Haconiwa.spawn "/etc/haconiwa/haco.d/test001.haco"
      end
    end
  end
end
