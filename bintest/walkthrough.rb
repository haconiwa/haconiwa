require 'open3'
require 'fileutils'

if `whoami` =~ /root/

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
  return Open3.capture2(BIN_PATH, subcommand, *args)
end

assert('walkthrough') do
  haconame = "test-#{rand(65535)}-#{$$}.haco"
  Dir.chdir File.dirname(HACONIWA_TMP_ROOT) do
    output, status = run_haconiwa "new", haconame, "--root=#{HACONIWA_TMP_ROOT}"

    assert_true status.success?, "Process did not exit cleanly: new"
    assert_true File.file? haconame
    check = system "ruby -c #{haconame}"
    assert_true check
    dummy_daemon = %q(["/bin/sh", "-c", "trap exit 15; while true; do : ; done"])
    system %Q(sed -i 's!config.init_command.*!config.init_command = #{dummy_daemon}!' #{haconame})
    system %Q(sed -i 's/# config.daemonize\!/config.daemonize\!/' #{haconame})

    output, status = run_haconiwa "create", haconame
    assert_true status.success?, "Process did not exit cleanly: create"

    assert_true File.directory? "#{HACONIWA_TMP_ROOT}/root"
    assert_true (/^3\.\d\.\d$/).match(File.read("#{HACONIWA_TMP_ROOT}/etc/alpine-release"))

    output, status = run_haconiwa "run", haconame
    assert_true status.success?, "Process did not exit cleanly: run"
    processes = `ps axf`
    assert_include processes, "haconiwa run #{haconame}"
    assert_include processes, "while true"

    output, status = run_haconiwa "kill", haconame
    assert_true status.success?, "Process did not exit cleanly: kill"

    processes = `ps axf`
    assert_not_include processes, "haconiwa run #{haconame}"
  end
end

end
