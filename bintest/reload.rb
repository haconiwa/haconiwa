require 'open3'
require 'fileutils'
require 'timeout'
require 'securerandom'
require 'erb'

if `whoami` =~ /root/
### start sudo test

BIN_PATH = File.join(File.dirname(__FILE__), "../mruby/bin/haconiwa") unless defined?(BIN_PATH)
HACONIWA_TMP_ROOT2 = ENV['HACONIWA_TMP_ROOT2'] || "/tmp/haconiwa/work-#{rand(65535)}-#{$$}"
FileUtils.rm_rf   HACONIWA_TMP_ROOT2
FileUtils.mkdir_p File.dirname(HACONIWA_TMP_ROOT2)

at_exit do
  FileUtils.rm_rf File.dirname(HACONIWA_TMP_ROOT2)
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
  ppid = pid = nil
  begin
    Timeout.timeout 3 do
      ready = false
      until ready
        subprocess = `pstree -Al $(pgrep haconiwa | sort | head -1)`.chomp
        tree = subprocess.split(/(-[-+]-|\s+)/)
        ready = (tree.size >= 5)
        sleep 0.1
      end

      until File.exist?("/var/run/haconiwa-#{container_name}.pid")
        sleep 0.1
      end

      until File.exist?("/sys/fs/cgroup/cpu/#{container_name}/cpu.cfs_quota_us")
        sleep 0.1
      end

      ppid = File.read("/var/run/haconiwa-#{container_name}.pid").chomp.to_i
      until pid
        pid = ppid_to_pid(ppid)
      end
    end
    return [ppid, pid]
  rescue Timeout::Error => e
    warn "container creation may be failed... skipping: #{e.class}, #{e.message}"
  end
end

def ppid_to_pid(ppid)
  status = `find /proc -maxdepth 2 -regextype posix-basic -regex '/proc/[0-9]\\+/status'`.
           split.
           find {|f| File.read(f).include? "PPid:\t#{ppid}\n" rescue false }
  return nil unless status
  status.split('/')[2].to_i
end


assert('haconiwa container is reloadable') do
  haconame = "reload-#{rand(65535)}-#{$$}.haco"
  Dir.chdir File.dirname(HACONIWA_TMP_ROOT2) do
    @hash = SecureRandom.hex(4)
    @rootfs = "/var/lib/haconiwa/__test__#{@hash}"
    container_name = "cgroup-reload-test-#{@hash}"
    hacosrc = File.expand_path('fixtures/reload-test.haco', File.dirname(__FILE__))
    File.open(haconame, 'w') do |haco|
      haco.puts ERB.new(File.read(hacosrc)).result(binding)
    end

    output, status = run_haconiwa "create", haconame
    assert_true status.success?, "Process did not exit cleanly: create"

    output, status = run_haconiwa "run", haconame
    assert_true status.success?, "Process did not exit cleanly: run"
    ppid, pid = wait_haconiwa(container_name)

    quota = File.read("/sys/fs/cgroup/cpu/#{container_name}/cpu.cfs_quota_us").chomp
    # FIXME: Quota counter is created then bumped in first invocation at `create'...
    # So start with here
    assert_equal "40000", quota
    nofile = `cat /proc/#{pid}/limits | grep 'Max open files' | awk '{print $4}'`.chomp
    assert_equal "2048", nofile

    Process.kill :HUP, ppid

    begin
      Timeout.timeout 3 do
        until `cat /proc/#{pid}/limits | grep 'Max open files' | awk '{print $4}'`.chomp == "3072"
          sleep 0.1
        end
      end
    rescue Timeout::Error => e
      warn "reload may be failed... skipping: #{e.class}, #{e.message}"
    end

    quota2 = File.read("/sys/fs/cgroup/cpu/#{container_name}/cpu.cfs_quota_us").chomp
    assert_equal "50000", quota2
    nofile2 = `cat /proc/#{pid}/limits | grep 'Max open files' | awk '{print $4}'`.chomp
    assert_equal "3072", nofile2

    output, status = run_haconiwa "kill", haconame
    assert_true status.success?, "Process did not exit cleanly: kill"

    system "rm -rf /var/*.data"
    FileUtils.rm_rf @rootfs
  end
end

### end sudo test
end
