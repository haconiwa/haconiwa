##
## Haconiwa Test
##

assert("Haconiwa#hello") do
  t = Haconiwa.new "hello"
  assert_equal("hello", t.hello)
end

assert("Haconiwa#bye") do
  t = Haconiwa.new "hello"
  assert_equal("hello bye", t.bye)
end

assert("Haconiwa.hi") do
  assert_equal("hi!!", Haconiwa.hi)
end
