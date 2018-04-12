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

HACONIWA_TMP_ROOT = ENV['HACONIWA_TMP_ROOT'] || "/tmp/haconiwa/work-#{rand(65535)}-#{$$}"

FileUtils.rm_rf   HACONIWA_TMP_ROOT
FileUtils.mkdir_p File.dirname(HACONIWA_TMP_ROOT)

at_exit { FileUtils.rm_rf File.dirname(HACONIWA_TMP_ROOT) }

def run_haconiwa(subcommand, *args)
  STDERR.puts "[testcase]\thaconiwa #{[subcommand, *args].join(' ')}"
  o, s = Open3.capture2(BIN_PATH, subcommand, *args)
  if s.coredump?
    raise "[BUG] haconiwa got SEGV. Abort testing"
  end
  puts(o) if ENV['DEBUGGING']
  return [o, s]
end

assert('walkthrough') do
  haconame = "test-#{rand(65535)}-#{$$}.haco"
  Dir.chdir File.dirname(HACONIWA_TMP_ROOT) do
    test_name = "haconiwa-tester-#{$$}"

    FileUtils.rm_rf "/etc/haconiwa.conf.rb"
    output, status = run_haconiwa "new", "--global"
    assert_true status.success?, "Process did not exit cleanly: new --global"
    assert_true File.file? "/etc/haconiwa.conf.rb"

    output, status = run_haconiwa "new", haconame, "--root=#{HACONIWA_TMP_ROOT}", "--name=#{test_name}"

    assert_true status.success?, "Process did not exit cleanly: new"
    assert_true File.file? haconame
    check = system "ruby -c #{haconame}"
    assert_true check
    dummy_daemon = %q(["/bin/sh", "-c", "trap exit 15; while true; do : ; done"])
    system %Q(sed -i 's!config.init_command.*!config.init_command = #{dummy_daemon}!' #{haconame})
    system %Q(sed -i 's/# config.daemonize\!/config.daemonize\!/' #{haconame})
    # FIXME: /dev/shm does not exist after lxc-create'd on trusty?
    system %Q(sed -i '/config.mount_independent "shm"/d' #{haconame})

    # change to git strategy
    system %Q(sed -i 's!b.strategy.*!b.strategy = "git"!' #{haconame})
    system %Q(sed -i 's!b.os_type.*!b.git_url = "https://github.com/haconiwa/haconiwa-image-alpine"!' #{haconame})
    system %Q(sed -i 's!apk add.*!apk update\\napk upgrade\\napk --no-cache add ruby!' #{haconame})

    output, status = run_haconiwa "create", haconame
    assert_true status.success?, "Process did not exit cleanly: create"

    assert_true File.directory? "#{HACONIWA_TMP_ROOT}/root"
    assert_true (/^3\.\d\.\d$/).match(File.read("#{HACONIWA_TMP_ROOT}/etc/alpine-release"))

    output, status = run_haconiwa "run", "-T", haconame, "--", "/usr/bin/uptime"
    assert_true status.success?, "Process did not exit cleanly: run"

    assert_include output, "load average"

    output, status = run_haconiwa "run", haconame
    assert_true status.success?, "Process did not exit cleanly: run"

    processes = `ps axf`
    assert_include processes, "haconiwa run #{haconame}"
    assert_true File.exist?("/var/run/haconiwa-#{test_name}.pid"), "Haconiwa creates pid file"

    subprocess = nil
    tree = []
    begin
      Timeout.timeout 3 do
        ready = false
        until ready
          subprocess = `pstree -Al $(pgrep haconiwa | sort | head -1)`.chomp
          tree = subprocess.split(/(-[-+]-|\s+)/)
          ready = (tree.size >= 5)
          sleep 0.1
        end
      end
    rescue Timeout::Error => e
      warn "container creation may be failed... skipping: #{e.class}, #{e.message}"
    end

    assert_equal 2, tree.count("haconiwa")
    assert_equal "haconiwa", tree[0]
    assert_equal "---", tree[1]
    assert_equal "haconiwa", tree[2]
    assert_equal "---", tree[3]
    assert_equal "sh", tree[4]

    output, status = run_haconiwa "kill", haconame
    assert_true status.success?, "Process did not exit cleanly: kill"

    begin
      Timeout.timeout 1 do
        while (processes = `ps axf`).include?("haconiwa run #{haconame}")
          sleep 0.1
        end
      end
    rescue Timeout::Error => e
      warn "container cannot be killed... skipping: #{e.class}, #{e.message}"
    end
    assert_not_include processes, "haconiwa run #{haconame}"
  end
end

### end sudo test
end
