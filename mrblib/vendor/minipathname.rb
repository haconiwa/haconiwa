class Pathname
  def initialize(path)
    @path = path
  end

  def join(*paths)
    Pathname.new clean_slashes([@path, *paths].flatten.join('/'))
  end

  def to_s
    @path
  end

  def to_str
    to_s
  end

  def inspect
    "#<Pathname path=#{@path}>"
  end

  private
  def clean_slashes(newpath)
    while newpath.include?('//')
      newpath.gsub!('//', '/')
    end
    newpath
  end
end
