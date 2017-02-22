#assert("Haconiwa::LinuxRunner#confirm_existence_pid_file") do
#  barn = Haconiwa::Barn.new
#  base = Haconiwa::Base.new(barn)
#  runner = Haconiwa::LinuxRunner.new(base)
#
#  # Probably init is always running
#  t = Tempfile.new 'test'
#  t.close false
#
#  File.open(t.path, "w+") {|f| f.print "1" }
#  assert_raise(RuntimeError) { runner.send('confirm_existence_pid_file', t.path) }
#
#  # Because it is a pid that does not exist
#  File.open(t.path, "w+") {|f| f.print "-1000" }
#  assert_nothing_raised("You can delete the pid for processes that do not exist") { runner.send('confirm_existence_pid_file', t.path) }
#
#  assert_false(File.exist?(t.path))
#end
