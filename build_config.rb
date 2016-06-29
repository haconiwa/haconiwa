MRuby::Build.new do |conf|
  toolchain :gcc
  conf.gembox 'full-core'

  conf.gem :github => 'matsumoto-r/mruby-cgroup'
  conf.gem :github => 'matsumoto-r/mruby-capability'
  conf.gem :github => 'harasou/mruby-resource'
  conf.gem :github => 'iij/mruby-process'
  conf.gem :github => 'iij/mruby-dir'
  conf.gem :github => 'haconiwa/mruby-exec'
  conf.gem :github => 'haconiwa/mruby-namespace'
  conf.gem :github => 'haconiwa/mruby-mount'

  conf.gem '.'

  conf.cc do |cc|
    cc.defines = %w(DEBUG) if ENV['DEBUG']
    cc.option_define = '-D%s'
  end
end
