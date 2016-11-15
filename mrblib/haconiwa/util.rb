module Haconiwa
  module Util
    extend self
    def to_safe_shellargs(args)
      args.map {|a| Shellwords.escape(a) }
    end

    def safe_shell_fmt(fmt, *args)
      sprintf(fmt, *to_safe_shellargs(args))
    end
  end
end
