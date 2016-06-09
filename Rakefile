MRUBY_CONFIG=File.expand_path(ENV["MRUBY_CONFIG"] || "build_config.rb")
TEMPLATE_CONFIG=File.expand_path(ENV["TEMPLATE_CONFIG"] || "template_config.rb")
MRUBY_VERSION=ENV["MRUBY_VERSION"] || "1.2.0"

file :mruby do
  #sh "wget -O mruby.tar.gz https://github.com/mruby/mruby/archive/#{MRUBY_VERSION}.tar.gz"
  #sh "tar -xvzf mruby.tar.gz"
  #sh "rm mruby.tar.gz"
  #sh "mv mruby-#{MRUBY_VERSION} mruby"
  sh "git clone --depth=1 git://github.com/mruby/mruby.git"
end

desc "compile binary"
task :compile => :mruby do
  sh "cd mruby && rake all MRUBY_CONFIG=\"#{MRUBY_CONFIG}\""
end

desc "test"
task :test => :mruby do
  sh "cd mruby && rake all test MRUBY_CONFIG=\"#{MRUBY_CONFIG}\""
end

desc "cleanup"
task :clean do
  sh "cd mruby && rake deep_clean"
end

task :default => :compile
