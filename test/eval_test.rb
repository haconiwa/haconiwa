def writeto(path, cont)
  f = File.open(path, 'w+')
  f.puts cont
  f.close
  cont
end

assert("Util.get_base") do
  dsl = <<-HACO
Haconiwa.define do |c|
  c.metadata["Foo"] = "Buz1"
end
  HACO
  hacopath = "/tmp/test#{UUID.secure_uuid}-#{Process.pid}.haco"
  writeto(hacopath, dsl)

  res = Haconiwa::Util.get_base([hacopath])
  assert_equal Haconiwa::Barn, res.class
  assert_equal "Buz1", res.metadata["Foo"]

  system "rm -f #{hacopath}"
end

assert("Util.get_script_and_eval") do
  dsl = <<-HACO
Haconiwa.define do |c|
  c.metadata["Foo"] = "Buz1"
end
  HACO
  hacopath = "/tmp/test#{UUID.secure_uuid}-#{Process.pid}.haco"
  writeto(hacopath, dsl)

  res = Haconiwa::Util.get_script_and_eval([hacopath, "--", "/bin/zsh", "-l"])
  assert_equal Haconiwa::Barn, res[0].class
  assert_equal "Buz1", res[0].metadata["Foo"]
  assert_equal ["/bin/zsh", "-l"], res[1]

  system "rm -f #{hacopath}"
end
