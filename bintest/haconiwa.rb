require 'open3'

begin
  Haconiwa::VERSION
rescue NameError
  load File.join(File.dirname(__FILE__), "../mrblib/haconiwa/version.rb")
end

BIN_PATH = File.join(File.dirname(__FILE__), "../mruby/bin/haconiwa") unless defined?(BIN_PATH)

MRUBY_REVISION = File.read(File.join(File.dirname(__FILE__), "../mruby_version.lock")).chomp

assert('revision') do
  output, status = Open3.capture2(BIN_PATH, "revisions")

  assert_true status.success?, "Process did not exit cleanly"
  assert_include output, "MRUBY_CORE_REVISION"
  assert_include output, MRUBY_REVISION
end

assert('version') do
  output, status = Open3.capture2(BIN_PATH, "version")

  assert_true status.success?, "Process did not exit cleanly"
  assert_include output, "v#{Haconiwa::VERSION}"
end

assert('show help') do
  output, status = Open3.capture2(BIN_PATH)

  assert_true status.success?, "Process did not exit cleanly"
  %W(run attach version revisions).each do |subcommand|
    assert_include output, subcommand
  end
end
