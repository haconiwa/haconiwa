module Haconiwa
  def self.run_as_criu_action_script
    if ENV['CRTOOLS_SCRIPT_ACTION'] != "post-setup-namespaces"
      return 0
    end
    ::Syslog.open("haconiwa.action-script")

    dev_name_line = `nsenter --net -t #{ENV['CRTOOLS_INIT_PID']} ip addr show`.lines.
                      select {|l| l =~ /^[0-9]+:/ }.
                      select {|l| l !~ /\s+lo:/ }.
                      first
    Haconiwa::Logger.debug "dev_name_line = #{dev_name_line}"
    unless dev_name_line
      raise "Detecting default ip failed"
    end
    dev_name = dev_name_line.split(/\s+/)[1].split('@').first
    default_ip = `nsenter --net -t #{ENV['CRTOOLS_INIT_PID']} ip addr show #{dev_name}`.scan(/(\d+\.\d+\.\d+\.\d+\/\d{1,2})/).flatten.first
    new_ip = ENV['HACONIWA_NEW_IP']
    Haconiwa::Logger.debug "default ip = #{default_ip}, new ip = #{new_ip}"

    [
      "nsenter --net -t #{ENV['CRTOOLS_INIT_PID']} ip addr del #{default_ip} dev #{dev_name}",
      "nsenter --net -t #{ENV['CRTOOLS_INIT_PID']} ip addr add #{new_ip} dev #{dev_name}"
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
