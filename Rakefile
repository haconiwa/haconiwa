require 'fileutils'

if ENV["MRUBY_VERSION"] && !ENV["MRUBY_VERSION"].empty?
  MRUBY_VERSION = ENV["MRUBY_VERSION"]
else
  MRUBY_VERSION = File.read(File.expand_path "../mruby_version.lock", __FILE__).chomp
end

file :mruby do
  cmd = "git clone --depth=1 https://github.com/mruby/mruby.git"
  case MRUBY_VERSION
  when /\A[a-fA-F0-9]+\z/
    cmd << " && cd mruby"
    cmd << " && git fetch --depth=100 && git checkout #{MRUBY_VERSION}"
  when /\A\d\.\d\.\d\z/
    cmd << " && cd mruby"
    cmd << " && git fetch --tags && git checkout $(git rev-parse #{MRUBY_VERSION})"
  when "master"
    # skip
  else
    fail "Invalid MRUBY_VERSION spec: #{MRUBY_VERSION}"
  end
  sh cmd
end

APP_NAME=ENV["APP_NAME"] || "haconiwa"
APP_ROOT=ENV["APP_ROOT"] || Dir.pwd
# avoid redefining constants in mruby Rakefile
mruby_root=File.expand_path(ENV["MRUBY_ROOT"] || "#{APP_ROOT}/mruby")
mruby_config=File.expand_path(ENV["MRUBY_CONFIG"] || "build_config.rb")
ENV['MRUBY_ROOT'] = mruby_root
ENV['MRUBY_CONFIG'] = mruby_config
if !Dir.exist?(mruby_root) or !File.exist?("#{mruby_root}/Rakefile")
  FileUtils.rm_rf mruby_root
  Rake::Task[:mruby].invoke
end

Dir.chdir(mruby_root)
load "#{mruby_root}/Rakefile"

desc "Make conistent mruby version"
task :consistent do
  match = system %q(test "$(cat ../mruby_version.lock)" = "$( git rev-parse HEAD )")
  if match
    STDERR.puts "mruby version is consistent to mruby_version.lock"
  else
    STDERR.puts "making mruby version consistent to mruby_version.lock..."
    Dir.chdir("../") do
      FileUtils.rm_rf mruby_root
      Rake::Task[:mruby].invoke
    end
  end
end

bin_path = ENV['INSTALL_DIR'] || "#{MRUBY_ROOT}/bin"
exes = %w(mruby mrbc mrbtest haconiwa).map{|bin| MRuby.targets['host'].exefile("#{bin_path}/#{bin}") }
desc "compile host binary"
task :compile => exes do
  MRuby.targets['host'].print_build_summary
end

desc "compile all binary"
task :compile_all => [:all] do
  bins = ["mruby", "mirb", APP_NAME]
  bins.each do |binname|
    %W(#{mruby_root}/build/x86_64-pc-linux-gnu/bin/#{binname} #{mruby_root}/build/x86_64-pc-linux-gnu_mirb/bin/#{binname}).each do |bin|
      sh "strip --strip-unneeded #{bin}" if File.exist?(bin)
    end
  end
end

namespace :test do
  desc "run mruby & unit tests"
  # only build mtest for host
  task :mtest => :compile do
    # in order to get mruby/test/t/synatx.rb __FILE__ to pass,
    # we need to make sure the tests are built relative from mruby_root
    MRuby.each_target do |target|
      # only run unit tests here
      target.enable_bintest = false
      run_test if target.test_enabled?
    end
  end

  def clean_env(envs)
    old_env = {}
    envs.each do |key|
      old_env[key] = ENV[key]
      ENV[key] = nil
    end
    yield
    envs.each do |key|
      ENV[key] = old_env[key]
    end
  end

  desc "run integration tests"
  task :bintest => :compile do
    MRuby.each_target do |target|
      clean_env(%w(MRUBY_ROOT MRUBY_CONFIG)) do
        run_bintest if target.bintest_enabled?
      end
    end
  end
end

desc "run all tests"
Rake::Task['test'].clear
task :test => "test:bintest"

desc "cleanup"
task :clean do
  sh "rake deep_clean"
end

desc "install haconiwa here in system"
task :install do
  target = ENV['INSTALL_TARGET'] || "#{ENV['prefix'] || ENV['PREFIX']}/bin"
  FileUtils.mkdir_p target
  sh "install #{mruby_root}/build/x86_64-pc-linux-gnu/bin/haconiwa  #{target}"
  sh "install #{mruby_root}/build/x86_64-pc-linux-gnu_mirb/bin/mirb #{target}/hacoirb"
  sh "install #{mruby_root}/build/x86_64-pc-linux-gnu/bin/mruby     #{target}/hacorb"
end

load File.expand_path("../mrblib/haconiwa/version.rb", __FILE__)
pwd = File.expand_path("..", __FILE__)
namespace :release do
  task :clean do
    sh "rm -rf #{pwd}/tmp/* #{pwd}/pkg/*"
  end

  task :copy => ["release:clean", :compile_all] do
    sh "cp #{mruby_root}/build/x86_64-pc-linux-gnu/bin/mruby     #{pwd}/tmp/hacorb"
    sh "cp #{mruby_root}/build/x86_64-pc-linux-gnu_mirb/bin/mirb #{pwd}/tmp/hacoirb"
    sh "cp #{mruby_root}/build/x86_64-pc-linux-gnu/bin/haconiwa  #{pwd}/tmp/haconiwa"
  end

  task :tarball => :copy do
    sh "cd #{pwd}/tmp && tar cvzf haconiwa-v#{Haconiwa::VERSION}.x86_64-pc-linux-gnu.tgz * && cp *.tgz ../pkg"
  end

  task :run_ghr do
    sh "cd #{pwd} && test \"$(git rev-parse --abbrev-ref HEAD)\" = 'master'"
    sh "cd #{pwd} && git pull --rebase --prune origin master"
    sh "cd #{pwd} && ghr -u haconiwa v#{Haconiwa::VERSION} pkg/"
    sh "cd #{pwd} && git fetch origin"
  end

  task :shipit => [:tarball, :run_ghr]
end

desc "Re-gen package required filez"
task :package_regen do
  require 'time'
  require 'yaml'
  require 'erb'
  Dir.chdir pwd do
    data = YAML.load_file("packages/templates/changelog.yml")
    @latest = data["latest"]
    @changelog = data["changelog"]

    deb = ERB.new(File.read("packages/templates/deb-changelog.erb")).result(binding).strip
    File.write("packages/deb/debian/changelog", deb)

    rpm = ERB.new(File.read("packages/templates/rpm-spec.erb")).result(binding).strip
    File.write("packages/rpm/haconiwa.spec", rpm)

    docker_deb = ERB.new(File.read("packages/templates/Dockerfile.debian.erb")).result(binding)
    File.write("packages/dockerfiles/Dockerfile.debian", docker_deb)

    docker_rpm = ERB.new(File.read("packages/templates/Dockerfile.centos.erb")).result(binding)
    File.write("packages/dockerfiles/Dockerfile.centos", docker_rpm)

    STDERR.puts "regen successful! please commit all files to git tree"
  end
end


desc "release the binary (using ghr(2))"
task :release => "release:shipit"
task :default => :test
