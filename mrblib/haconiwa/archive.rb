module Haconiwa
  class Archive
    def initialize(base, options)
      @root = base.rootfs
      @dest = options[:dest]
      @type = detect_zip_type((options[:type] || @dest).to_s)
      @tar_options = options[:tar_options] || []
      @verbose = options[:verbose]
      if @dry_run = options[:dry_run]
        @dest = '-'
      end
      @cmd = RunCmd.new("archive.#{@dry_run ? 'dry-run' : 'run'}")
    end

    def do_archive
      @cmd.run(to_tar_command)
      if @dry_run
        Logger.puts "Dry-run OK"
      else
        Logger.puts "Created: #{@dest}"
      end
    end

    private
    def to_tar_command
      pre = post = ""
      if @dry_run
        pre = "size=`"
        post = " | wc -c` && echo 'Assumed archive size(bytes): '$size"
      end
      "#{pre}tar #{gen_tar_options.join(' ')} ./#{post}"
    end

    def gen_tar_options
      tar_options = @tar_options.dup
      tar_options << "-c"
      tar_options << @type
      tar_options << "-v" if @verbose
      tar_options = tar_options.compact.uniq
      tar_options << "--exclude=.git"
      tar_options << "-f"
      tar_options << @dest
      tar_options << "-C"
      tar_options << @root.to_str
    end

    def detect_zip_type(path)
      extname = ::File.extname(path)
      extname = path if extname.empty?
      case extname
      when "gzip", "gz", ".gz", ".tgz"
        "-z"
      when "bzip2", "bz2", ".bz2"
        "-j"
      when "lzma2", "xz", ".xz"
        "-J"
      else
        Logger.warning "[Warning] Archive type detection failed: #{path}. Skip"
        nil
      end
    end
  end
end
