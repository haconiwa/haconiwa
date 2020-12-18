LIBCAP_VERSION = "2.32"
LIBCAP_TAG = "libcap-#{LIBCAP_VERSION}"
LIBCAP_TARGET_COMMIT = "4afef829cbe366a2339cb095edc614afb9b1aa72"
LIBCAP_CHECKOUT_URL = "https://kernel.googlesource.com/pub/scm/linux/kernel/git/morgan/libcap.git"

def gem_config(conf)
  # If your haconiwa must check runner and hacofile's owner, please uncomment
  # conf.cc.defines << "HACONIWA_SECURE_RUN"
  conf.cc.defines << "HACONIWA_USE_CRIU" unless ENV["CI"]
  conf.gem File.expand_path(File.dirname(__FILE__))
end

MRuby::Build.new do |conf|
  toolchain :gcc

  conf.enable_bintest
  conf.enable_debug
  conf.enable_test

  gem_config(conf)
  conf.gem github: 'matsumotory/mruby-localmemcache'
end

# Just build for Linux...
MRuby::Build.new('x86_64-pc-linux-gnu') do |conf|
  toolchain :gcc

  conf.enable_debug

  gem_config(conf)
end

MRuby::Build.new('x86_64-pc-linux-gnu_mirb') do |conf|
  toolchain :gcc

  gem_config(conf)
  conf.gem core: 'mruby-bin-mirb'
  conf.bins = ["mirb"]
end

# MRuby::CrossBuild.new('i686-pc-linux-gnu') do |conf|
#   toolchain :gcc

#   [conf.cc, conf.cxx, conf.linker].each do |cc|
#     cc.flags << "-m32"
#   end

#   gem_config(conf)
# end
