assert("Haconiwa::LinuxRunner#confirm_existence_pid_file") do
  begin
    barn = Haconiwa::Barn.new
    base = Haconiwa::Base.new(barn)
    runner = Haconiwa::LinuxRunner.new(base)

    path = "/tmp/confirm_existence_pid_file-test-#{$$}.pid"

    File.open(path, "w+") {|f| f.print $$.to_s }
    assert_raise(RuntimeError) { runner.send('confirm_existence_pid_file', path) }

    # Because it is a pid that does not exist
    File.open(path, "w+") {|f| f.print "-1000" }
    assert_nothing_raised("You can delete the pid for processes that do not exist") { runner.send('confirm_existence_pid_file', path) }

    assert_false(File.exist?(path))
  ensure
    system "rm -rf #{path}" if path
  end
end
