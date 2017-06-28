require 'open3'
require 'fileutils'
require 'timeout'

if `whoami` =~ /root/
### start sudo test

begin
  Haconiwa::VERSION
rescue NameError
  load File.join(File.dirname(__FILE__), "../mrblib/haconiwa/version.rb")
end

BIN_PATH = File.join(File.dirname(__FILE__), "../mruby/bin/haconiwa") unless defined?(BIN_PATH)

HACONIWA_TMP_ROOT4 = ENV['HACONIWA_TMP_ROOT2'] || "/tmp/haconiwa/work-#{rand(65535)}-#{$$}"
FileUtils.rm_rf   HACONIWA_TMP_ROOT4
FileUtils.mkdir_p File.dirname(HACONIWA_TMP_ROOT4)

at_exit do
  FileUtils.rm_rf File.dirname(HACONIWA_TMP_ROOT4)
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

def run_parallel(*args)
  STDERR.puts "[testcase]\tparallel #{[*args].join(' ')}"
  o, e, s = Open3.capture3("parallel", *args)
  if s.coredump?
    raise "[BUG] haconiwa got SEGV. Abort testing"
  end
  puts(o, "--stderr--", e) if ENV['DEBUGGING']
  return [o, e, s]
end

assert('haconiwa container cannot be invoked when same process is up') do
  haconame = "parallel-#{rand(65535)}-#{$$}.haco"
  Dir.chdir File.dirname(HACONIWA_TMP_ROOT4) do
    @hash = SecureRandom.hex(4)
    @rootfs = "/var/lib/haconiwa/__test__#{@hash}"
    container_name = "parallel-test-#{@hash}"
    hacosrc = File.expand_path('fixtures/just-sleep.haco.erb', File.dirname(__FILE__))
    File.open(haconame, 'w') do |haco|
      haco.puts ERB.new(File.read(hacosrc)).result(binding)
    end

    output, status = run_haconiwa "create", haconame
    assert_true status.success?, "Process did not exit cleanly: create"

    _, err, _ =run_parallel "-j", "10", BIN_PATH, "run", haconame, "--", "/bin/sleep", ":::", *((10..19).to_a.map(&:to_s))
    Timeout.timeout 2 do
      until File.exist?("/var/run/haconiwa-#{container_name}.pid")
        sleep 0.1
      end
    end

    assert_equal 9, err.scan('cannot set lock').size

    cnt = `pgrep haconiwa | wc -l`.chomp.to_i
    assert_equal 2, cnt

    system "killall -9 sleep"
    FileUtils.rm_rf @rootfs
  end
end


end
