MRuby::Gem::Specification.new('haconiwa') do |spec|
  spec.license = 'GPL v3'
  spec.authors = 'Uchio Kondo'

  spec.bins = ["haconiwa"]

  spec.add_dependency 'mruby-process'   , :mgem => 'mruby-process'
  spec.add_dependency 'mruby-io'        , :mgem => 'mruby-io'
  spec.add_dependency 'mruby-argtable'  , :mgem => 'mruby-argtable'
  spec.add_dependency 'mruby-eval'      , :core => 'mruby-eval'
  spec.add_dependency 'mruby-bin-mirb'  , :core => 'mruby-bin-mirb'
  spec.add_dependency 'mruby-bin-mruby' , :core => 'mruby-bin-mruby'
  spec.add_dependency 'mruby-print'     , :core => 'mruby-print'
  spec.add_dependency 'mruby-array-ext' , :core => 'mruby-array-ext'
  spec.add_dependency 'mruby-string-ext', :core => 'mruby-string-ext'
  spec.add_dependency 'mruby-time'      , :core => 'mruby-time'

  spec.add_dependency 'mruby-cgroup'    , :github => 'matsumoto-r/mruby-cgroup'
  spec.add_dependency 'mruby-capability', :github => 'matsumoto-r/mruby-capability'
  spec.add_dependency 'mruby-resource'  , :github => 'harasou/mruby-resource'
  spec.add_dependency 'mruby-dir'       , :github => 'iij/mruby-dir' # with Dir#chroot
  spec.add_dependency 'mruby-procutil'  , :github => 'haconiwa/mruby-procutil'
  spec.add_dependency 'mruby-exec'      , :github => 'haconiwa/mruby-exec'
  spec.add_dependency 'mruby-namespace' , :github => 'haconiwa/mruby-namespace'
  spec.add_dependency 'mruby-mount'     , :github => 'haconiwa/mruby-mount'

end
