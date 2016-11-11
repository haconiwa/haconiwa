require 'open3'
require 'fileutils'

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
  return Open3.capture2(BIN_PATH, subcommand, *args)
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

    subprocess = `pstree -Al $(pgrep haconiwa) | awk -F'---' '{print $2}'`
    assert_false subprocess.empty?

    output, status = run_haconiwa "ps"
    assert_include output, "NAME"
    assert_include output, test_name
    assert_include output, HACONIWA_TMP_ROOT

    output, status = run_haconiwa "kill", haconame
    assert_true status.success?, "Process did not exit cleanly: kill"

    processes = `ps axf`
    assert_not_include processes, "haconiwa run #{haconame}"
  end
end

assert('empty ps') do
  output, status = run_haconiwa "ps"
  assert_true status.success?, "Process did not exit cleanly: ps"
  assert_equal 1, output.chomp.lines.to_a.size
end

### end sudo test
end
