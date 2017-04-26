require 'open3'
require 'fileutils'
require 'timeout'
require 'securerandom'
require 'erb'
require 'json'

if `whoami` =~ /root/
### start sudo test

BIN_PATH = File.join(File.dirname(__FILE__), "../mruby/bin/haconiwa") unless defined?(BIN_PATH)
HACONIWA_TMP_ROOT3 = ENV['HACONIWA_TMP_ROOT3'] || "/tmp/haconiwa/work-#{rand(65535)}-#{$$}"
FileUtils.rm_rf   HACONIWA_TMP_ROOT3
FileUtils.mkdir_p File.dirname(HACONIWA_TMP_ROOT3)

at_exit do
  FileUtils.rm_rf File.dirname(HACONIWA_TMP_ROOT3)
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

def wait_haconiwa(container_name)
  begin
    Timeout.timeout 3 do
      ready = false
      until ready
        subprocess = `pstree -Al $(pgrep haconiwa | sort | head -1)`.chomp
        tree = subprocess.split(/(-[-+]-|\s+)/)
        ready = (tree.size >= 7 && tree.last == "`-4*[{haconiwa}]")
        sleep 0.1
      end
    end
  rescue Timeout::Error => e
    warn "container creation may be failed... skipping: #{e.class}, #{e.message}"
  end
end

assert('haconiwa container is reloadable') do
  haconame = "hooks-#{rand(65535)}-#{$$}.haco"
  Dir.chdir File.dirname(HACONIWA_TMP_ROOT3) do
    @hash = SecureRandom.hex(4)
    @rootfs = "/var/lib/haconiwa/__test__#{@hash}"
    container_name = "hooks-test-#{@hash}"
    hacosrc = File.expand_path('fixtures/hooks-test.haco', File.dirname(__FILE__))
    File.open(haconame, 'w') do |haco|
      haco.puts ERB.new(File.read(hacosrc)).result(binding)
    end

    output, status = run_haconiwa "create", haconame
    assert_true status.success?, "Process did not exit cleanly: create"

    output, status = run_haconiwa "run", haconame
    assert_true status.success?, "Process did not exit cleanly: run"
    wait_haconiwa(container_name)

    output, status = run_haconiwa "kill", haconame
    assert_true status.success?, "Process did not exit cleanly: kill"

    while `pgrep haconiwa | wc -l`.chomp != '0'
      sleep 0.1
    end

    result = JSON.parse(File.read "#{@rootfs}/log.json")
    %w(before_fork before_start_wait after_fork teardown_container).each do |hook|
      assert_equal "OK", result[hook]
    end
    hook_txt = File.read "#{@rootfs}/after_chroot.txt"
    assert_equal "OK, this file is from after_chroot hook", hook_txt.chomp

    FileUtils.rm_rf @rootfs
  end
end

### end sudo test
end
