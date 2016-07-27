module UUID
  def self.srand
    Kernel.srand(Time.now.to_i ^ Process.pid)
  end

  def self.uuid(fmt="%04x%04x-%04x-%04x-%04x-%04x%04x%04x")
    s = []
    8.times { s << rand(256 * 256) }
    fmt % s
  end

  # requires urandom device
  def self.secure_uuid(fmt="%04x%04x-%04x-%04x-%04x-%04x%04x%04x")
    s = []
    b = File.read("/dev/urandom", 16).bytes
    8.times {|i| s << ((b[i] + 1) * (b[i + 8] + 1) - 1) }
    fmt % s
  end
end
