# mruby-haconiwa-core   [![Build Status](https://travis-ci.org/udzura/mruby-haconiwa-core.svg?branch=master)](https://travis-ci.org/udzura/mruby-haconiwa-core)
Haconiwa class
## install by mrbgems
- add conf.gem line to `build_config.rb`

```ruby
MRuby::Build.new do |conf|

    # ... (snip) ...

    conf.gem :github => 'udzura/mruby-haconiwa-core'
end
```
## example
```ruby
p Haconiwa.hi
#=> "hi!!"
t = Haconiwa.new "hello"
p t.hello
#=> "hello"
p t.bye
#=> "hello bye"
```

## License
under the MIT License:
- see LICENSE file
