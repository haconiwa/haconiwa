Haconiwa.watch do |config|
  config.watch :cluster do |event|
    puts "Receive!" + event.raw_resp.inspect
    puts "Receive!" + event.cluster.inspect
  end
end
