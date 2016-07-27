DEFS_FILE = File.expand_path('../src/REVISIONS.defs', __FILE__) unless defined?(DEFS_FILE)
system "rm -rf #{DEFS_FILE}"

MRuby::Gem::Specification.new('haconiwa') do |spec|
  spec.license = 'GPL v3'
  spec.authors = 'Uchio Kondo'

  spec.bins = ["haconiwa"]

  spec.add_dependency 'mruby-process'   , :mgem => 'mruby-process'
  spec.add_dependency 'mruby-io'        , :mgem => 'mruby-io'
  spec.add_dependency 'mruby-eval'      , :core => 'mruby-eval'
  #spec.add_dependency 'mruby-bin-mirb'  , :core => 'mruby-bin-mirb'
  spec.add_dependency 'mruby-bin-mruby' , :core => 'mruby-bin-mruby'
  spec.add_dependency 'mruby-print'     , :core => 'mruby-print'
  spec.add_dependency 'mruby-array-ext' , :core => 'mruby-array-ext'
  spec.add_dependency 'mruby-string-ext', :core => 'mruby-string-ext'
  spec.add_dependency 'mruby-time'      , :core => 'mruby-time'
  spec.add_dependency 'mruby-sprintf'   , :core => 'mruby-sprintf'
  spec.add_dependency 'mruby-random'    , :core => 'mruby-random'

  spec.add_dependency 'mruby-cgroup'    , :github => 'matsumoto-r/mruby-cgroup'
  spec.add_dependency 'mruby-capability', :github => 'matsumoto-r/mruby-capability'
  spec.add_dependency 'mruby-resource'  , :github => 'harasou/mruby-resource'
  spec.add_dependency 'mruby-dir'       , :github => 'iij/mruby-dir' # with Dir#chroot
  spec.add_dependency 'mruby-procutil'  , :github => 'haconiwa/mruby-procutil'
  spec.add_dependency 'mruby-exec'      , :github => 'haconiwa/mruby-exec'
  spec.add_dependency 'mruby-namespace' , :github => 'haconiwa/mruby-namespace'
  spec.add_dependency 'mruby-mount'     , :github => 'haconiwa/mruby-mount'
  spec.add_dependency 'mruby-process-sys' , :github => 'haconiwa/mruby-process-sys'
  spec.add_dependency 'mruby-argtable'  , :github => 'udzura/mruby-argtable', :branch => 'static-link-argtable3'
  spec.add_dependency 'mruby-signal'    , :github => 'ksss/mruby-signal'

  def spec.save_dependent_mgem_revisions
    file DEFS_FILE do
      f = open(DEFS_FILE, 'w')
      corerev = `git rev-parse HEAD`.chomp
      f.puts %Q<{"MRUBY_CORE_REVISION", "#{corerev}"},>
      `find ./build/mrbgems -type d -name 'mruby-*' | sort`.each_line do |l|
        l = l.chomp
        if File.directory? "#{l}/.git"
          gemname = l.split('/').last
          rev = `git --git-dir #{l}/.git rev-parse HEAD`.chomp
          f.puts %Q<{"#{gemname}", "#{rev}"},>
        end
      end
      f.close
      puts "GEN\t#{DEFS_FILE}"
    end

    libmruby_a = libfile("#{build.build_dir}/lib/libmruby")
    file libmruby_a => DEFS_FILE
  end

  spec.save_dependent_mgem_revisions
end
