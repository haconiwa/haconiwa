module Haconiwa
  module Util
    extend self
    def to_safe_shellargs(args)
      args.map {|a|
        if a.empty? or a =~ /^\s+$/
          ""
        else
          Shellwords.escape(a)
        end
      }
    end

    def safe_shell_fmt(fmt, *args)
      sprintf(fmt, *to_safe_shellargs(args))
    end
  end
end
