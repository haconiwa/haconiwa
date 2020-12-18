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
  # conf.gem github: 'matsumotory/mruby-localmemcache'
  conf.gem core: 'mruby-bin-mirb'
  conf.bins = ["mruby", "mirb"]
end
