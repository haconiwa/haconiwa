assert("Base#metadata") do
  barn = Haconiwa.define do |c|
    c.metadata["Foo"] = "Bar"
  end

  haco = barn.containers_real_run.first
  assert_equal "Bar", haco.metadata["Foo"]
end
