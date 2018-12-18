class OnMemoryLogger
  class MyError < StandardError
  end

  def initialize
    @store = {}
  end
  attr_reader :store

  def exception(*args)
    err(*args)
    raise(MyError)
  end

  def err(*args)
    @store[:err] = args
  end

  def warning(*args)
    @store[:warning] = args
  end

  def notice(*args)
    @store[:notice] = args
  end

  def info(*args)
    @store[:info] = args
  end

  def puts(*args)
    info(*args)
    @store[:stdout] = args
  end

  def debug(*args)
    @store[:debug] = args
  end
end

assert("Haconiwa::Logger") do
  Haconiwa::Logger.instance # initialize
  old = Haconiwa::Logger.set_default_instance!(OnMemoryLogger.new)

  Haconiwa::Logger.err("test", "error")
  assert_equal(["test", "error"], Haconiwa::Logger.instance.store[:err])

  Haconiwa::Logger.warning("test", "warning")
  assert_equal(["test", "warning"], Haconiwa::Logger.instance.store[:warning])

  Haconiwa::Logger.notice("test", "notice")
  assert_equal(["test", "notice"], Haconiwa::Logger.instance.store[:notice])

  Haconiwa::Logger.info("test", "info")
  assert_equal(["test", "info"], Haconiwa::Logger.instance.store[:info])

  Haconiwa::Logger.debug("test", "debug")
  assert_equal(["test", "debug"], Haconiwa::Logger.instance.store[:debug])

  Haconiwa::Logger.puts("test", "puts")
  assert_equal(["test", "puts"], Haconiwa::Logger.instance.store[:info])
  assert_equal(["test", "puts"], Haconiwa::Logger.instance.store[:stdout])

  err = nil
  begin
    Haconiwa::Logger.exception("test", "raise")
  rescue => e
    err = e
  end

  assert_equal(["test", "raise"], Haconiwa::Logger.instance.store[:err])
  assert_equal(OnMemoryLogger::MyError, e.class)

  Haconiwa::Logger.set_default_instance!(old)
end
