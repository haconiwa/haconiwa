MRuby::Gem::Specification.new('haconiwa') do |spec|
  spec.license = 'GPL v3'
  spec.authors = 'Uchio Kondo'

  spec.bins = ["haconiwa"]

  spec.add_dependency 'mruby-cgroup'    , :github => 'matsumoto-r/mruby-cgroup'
  spec.add_dependency 'mruby-capability', :github => 'matsumoto-r/mruby-capability'
  spec.add_dependency 'mruby-resource'  , :github => 'harasou/mruby-resource'
  spec.add_dependency 'mruby-process'   , :github => 'iij/mruby-process'
  spec.add_dependency 'mruby-dir'       , :github => 'iij/mruby-dir'
  spec.add_dependency 'mruby-exec'      , :github => 'haconiwa/mruby-exec'
  spec.add_dependency 'mruby-namespace' , :github => 'haconiwa/mruby-namespace'
  spec.add_dependency 'mruby-mount'     , :github => 'haconiwa/mruby-mount'

end
