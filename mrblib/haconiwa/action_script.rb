module Haconiwa
  def self.run_as_criu_action_script
    if ENV['CRTOOLS_SCRIPT_ACTION'] != "post-setup-namespaces"
      return 0
    end
    log_level = ( ENV['DEBUG'] || ENV['VERBOSE'] ) ? Haconiwa::Logger::DEBUG : Haconiwa::Logger::INFO
    Haconiwa::Logger.instance._setup("haconiwa.action-script", log_level)

    dev_name_line = `nsenter --net -t #{ENV['CRTOOLS_INIT_PID']} ip addr show`.lines.
                      select {|l| l =~ /^[0-9]+:/ }.
                      select {|l| l !~ /\s+lo:/ }.
                      select {|l| l =~ /#{ENV['HACONIWA_CONTAINER_NICNAME']}/ }.
                      first
    Haconiwa::Logger.debug "dev_name_line = #{dev_name_line}"
    unless dev_name_line
      raise "Detecting default ip failed"
    end
    dev_name = dev_name_line.split(/\s+/)[1].split('@').first
    default_gw_ip = ENV['HACONIWA_CONTAINER_DEFAULT_GW']
    default_ip = `nsenter --net -t #{ENV['CRTOOLS_INIT_PID']} ip addr show #{dev_name}`.scan(/(\d+\.\d+\.\d+\.\d+\/\d{1,2})/).flatten.first
    new_ip = ENV['HACONIWA_NEW_IP']
    Haconiwa::Logger.debug "default ip = #{default_ip}, new ip = #{new_ip}"

    if default_ip == new_ip
      return 0 # Skipping recreate network
    end

    [
      "nsenter --net -t #{ENV['CRTOOLS_INIT_PID']} ip addr del #{default_ip} dev #{dev_name}",
      "nsenter --net -t #{ENV['CRTOOLS_INIT_PID']} ip addr add #{new_ip} dev #{dev_name}",
      "nsenter --net -t #{ENV['CRTOOLS_INIT_PID']} ip route add default via #{default_gw_ip}",
    ].each do |cmd|
      unless system(cmd)
        Haconiwa::Logger.exception "IP assign failed: cmd=#{cmd}"
      end
    end

    if ENV['DEBUG'] || ENV['VERBOSE']
      debug = `nsenter --net -t #{ENV['CRTOOLS_INIT_PID']} ip a`
      Haconiwa::Logger.debug "Restored and re-assigned network:\n" + debug
    end

    return 0
  end
end
