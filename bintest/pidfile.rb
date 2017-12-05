require 'open3'
require 'fileutils'
require 'timeout'
require 'erb'
require 'securerandom'

if `whoami` =~ /root/
### start sudo test

begin
  Haconiwa::VERSION
rescue NameError
  load File.join(File.dirname(__FILE__), "../mrblib/haconiwa/version.rb")
end

BIN_PATH = File.join(File.dirname(__FILE__), "../mruby/bin/haconiwa") unless defined?(BIN_PATH)

HACONIWA_TMP_ROOT5 = ENV['HACONIWA_TMP_ROOT5'] || "/tmp/haconiwa/work-#{rand(65535)}-#{$$}"
FileUtils.rm_rf   HACONIWA_TMP_ROOT5
FileUtils.mkdir_p File.dirname(HACONIWA_TMP_ROOT5)

at_exit do
  FileUtils.rm_rf File.dirname(HACONIWA_TMP_ROOT5)
end

def run_haconiwa(subcommand, *args)
  STDERR.puts "[testcase]\thaconiwa #{[subcommand, *args].join(' ')}"
  o, s = Open3.capture2(BIN_PATH, subcommand, *args)
  if s.coredump?
    raise "[BUG] haconiwa got SEGV. Abort testing"
  end
  puts(o) if ENV['DEBUGGING']
  return [o, s]
end

def run_haconiwa_seq(seq, subcommand, *args)
  STDERR.puts "[testcase]\thaconiwa #{[subcommand, *args].join(' ')} ##{seq}"
  o, s = Open3.capture2({"SEQ" => seq.to_s}, BIN_PATH, subcommand, *args)
  if s.coredump?
    raise "[BUG] haconiwa got SEGV. Abort testing"
  end
  puts(o) if ENV['DEBUGGING']
  return [o, s]
end

assert('haconiwa containers create pidfile and leap it on exit') do
  haconame = "pidfile-#{rand(65535)}-#{$$}.haco"
  Dir.chdir File.dirname(HACONIWA_TMP_ROOT5) do
    hash = SecureRandom.hex(4)
    @hash = "#{@hash}-\#{ENV['SEQ']}"
    @rootfs = "/var/lib/haconiwa/__test__#{@hash}"
    container_name = "pidfile-test-#{hash}"
    @sleeptime = 1
    hacosrc = File.expand_path('fixtures/just-sleep.haco.erb', File.dirname(__FILE__))
    File.open(haconame, 'w') do |haco|
      data = ERB.new(File.read(hacosrc)).result(binding)
      puts data
      haco.puts data
    end


    output, status = run_haconiwa "create", haconame
    assert_true status.success?, "Process did not exit cleanly: create"

    10.times do |i|
      output, status = run_haconiwa_seq(i, "run", haconame)
      assert_true status.success?, "Haconiwa invocation failed: ##{i}"
      Timeout.timeout 3 do
        while File.exist?("/var/run/haconiwa-pidfile-test-#{@hash}-#{i}.pid")
          sleep 0.1
        end
      end
      sleep 1
      assert_false File.exist?("/var/run/haconiwa-pidfile-test-#{@hash}-#{i}.pid"), "Remove pid file: ##{i}"
    end
  end
end

end
