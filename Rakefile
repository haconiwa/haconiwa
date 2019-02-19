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
    cmd << " && git fetch --depth=500 && git checkout #{MRUBY_VERSION}"
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
if !File.exist?(mruby_root) or !File.exist?("#{mruby_root}/Rakefile")
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
    $verbose = !!ENV['MTEST_VERBOSE']
    #$mrbtest_verbose = true
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
  task :bintest do
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
  task :changelog do
    require 'yaml'
    require "highline/import"
    changelog = "#{pwd}/packages/templates/changelog.yml"
    orig = YAML.load_file(changelog)

    version = ask("New version? [ex. 0.10.1]")
    description = ask("What is changed?")
    author = "%s <%s>" % [`git config user.name`.chomp, `git config user.email`.chomp]
    date = `env LANG=C date +'%a, %e %h %Y %H:%M:%S %z'`.chomp

    newlog = orig.dup
    newlog["changelog"].unshift(
      "version" => version.to_s,
      "messages" => [description.to_s],
      "author" => author,
      "date" => date
    )
    newlog["latest"] = version.to_s

    File.open(changelog, 'w') do |f|
      f.write YAML.dump(newlog)
    end
  end

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
    version_dot = Haconiwa::VERSION.gsub(/~/, '.')
    branch = `cd #{pwd} && git rev-parse --abbrev-ref HEAD`.chomp
    sh "cd #{pwd} && git pull --rebase --prune origin #{branch}"
    sh "cd #{pwd} && ghr -c #{branch} -u haconiwa v#{version_dot} pkg/"
    sh "cd #{pwd} && git fetch origin"
  end

  task :shipit => [:tarball, :run_ghr]

  desc "Build all of packages in parallel"
  multitask :packages => [:deb, :deb9, :bionic]

  task :deb do
    Dir.chdir(pwd) { sh "docker-compose build deb && docker-compose run deb" }
  end

  task :deb9 do
    Dir.chdir(pwd) { sh "docker-compose build deb9 && docker-compose run deb9" }
  end

  task :bionic do
    Dir.chdir(pwd) { sh "docker-compose build bionic && docker-compose run bionic" }
  end

  task :rpm do
    Dir.chdir(pwd) { sh "docker-compose build rpm && docker-compose run rpm" }
  end

  desc "release packages to packagecloud"
  task :packagecloud do
    Dir.chdir pwd do
      sh "package_cloud push udzura/haconiwa/ubuntu/bionic pkg/haconiwa_#{Haconiwa::VERSION}-1+bionic_amd64.deb"
      sh "package_cloud push udzura/haconiwa/ubuntu/xenial pkg/haconiwa_#{Haconiwa::VERSION}-1_amd64.deb"
      sh "package_cloud push udzura/haconiwa/debian/jessie pkg/haconiwa_#{Haconiwa::VERSION}-1_amd64.deb"
      sh "package_cloud push udzura/haconiwa/debian/stretch pkg/haconiwa_#{Haconiwa::VERSION}-1+debian9_amd64.deb"
      # sh "package_cloud push udzura/haconiwa/el/7 pkg/haconiwa-#{Haconiwa::VERSION}-1.el7.x86_64.rpm"
      # sh "package_cloud push udzura/haconiwa/fedora/23 pkg/haconiwa-#{Haconiwa::VERSION}-1.el7.x86_64.rpm"
      # sh "package_cloud push udzura/haconiwa/fedora/24 pkg/haconiwa-#{Haconiwa::VERSION}-1.el7.x86_64.rpm"
    end
  end
end

desc "Re-gen package required filez"
task :package_regen do
  require 'time'
  require 'yaml'
  require 'erb'
  Dir.chdir pwd do
    data = YAML.load_file("packages/templates/changelog.yml")
    @latest = data["latest"]
    @latest_dot = @latest.gsub(/~/, '.')
    @changelog = data["changelog"]

    deb = ERB.new(File.read("packages/templates/deb-changelog.erb")).result(binding).strip
    File.write("packages/deb/debian/changelog", deb + "\n")

    rpm = ERB.new(File.read("packages/templates/rpm-spec.erb")).result(binding).strip
    File.write("packages/rpm/haconiwa.spec", rpm + "\n")

    docker_deb = ERB.new(File.read("packages/templates/Dockerfile.debian.erb")).result(binding)
    File.write("packages/dockerfiles/Dockerfile.debian", docker_deb)

    docker_deb = ERB.new(File.read("packages/templates/Dockerfile.debian9.erb")).result(binding)
    File.write("packages/dockerfiles/Dockerfile.debian9", docker_deb)

    docker_deb = ERB.new(File.read("packages/templates/Dockerfile.bionic.erb")).result(binding)
    File.write("packages/dockerfiles/Dockerfile.bionic", docker_deb)

    docker_rpm = ERB.new(File.read("packages/templates/Dockerfile.centos.erb")).result(binding)
    File.write("packages/dockerfiles/Dockerfile.centos", docker_rpm)

    version = ERB.new(File.read("packages/templates/version.rb.erb")).result(binding)
    File.write("mrblib/haconiwa/version.rb", version)

    STDERR.puts "regen successful! please commit all files to git tree"
  end
end


desc "release the binary (using ghr(2))"
task :release => "release:shipit"
task :default => :test
