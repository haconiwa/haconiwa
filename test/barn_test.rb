assert("Barn#project_name") do
  basename = "example-#{UUID.secure_uuid('%04x')}"

  barn = Haconiwa::Barn.new
  base = Haconiwa::Base.new(barn)
  base.name = basename
  barn.containers << base
  barn.update_project_name!

  assert_equal basename, barn.project_name

  # Multiple containers
  basename1 = "example-#{UUID.secure_uuid('%04x')}"
  basename2 = "example-#{UUID.secure_uuid('%04x')}"
  expected = "haconiwa-" + ::SHA1.sha1_hex([basename1, basename2].sort.join(':'))

  barn2 = Haconiwa::Barn.new
  base1 = Haconiwa::Base.new(barn)
  base1.name = basename1
  base2 = Haconiwa::Base.new(barn)
  base2.name = basename2

  barn2.containers.concat [base1, base2]
  barn2.update_project_name!

  assert_equal expected, barn2.project_name
end
