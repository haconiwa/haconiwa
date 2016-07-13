require 'open3'

load File.join(File.dirname(__FILE__), "../../mrblib/haconiwa/version.rb")

BIN_PATH = File.join(File.dirname(__FILE__), "../mruby/bin/haconiwa")

assert('revision') do
  output, status = Open3.capture2(BIN_PATH, "revisions")

  assert_true status.success?, "Process did not exit cleanly"
  assert_include output, "MRUBY_CORE_REVISION"
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
