module ExpandPath
  # Code from mruby-io (https://github.com/iij/mruby-io/blob/master/mrblib/file.rb#L63)
  # But avoids the nested method def.

  def self.expand_path(path, default_dir = '.')
    expanded_path = concat_path(path, default_dir)
    drive_prefix = ""
    if File::ALT_SEPARATOR && expanded_path.size > 2 &&
        ("A".."Z").include?(expanded_path[0].upcase) && expanded_path[1] == ":"
      drive_prefix = expanded_path[0, 2]
      expanded_path = expanded_path[2, expanded_path.size]
    end
    expand_path_array = []
    if File::ALT_SEPARATOR && expanded_path.include?(File::ALT_SEPARATOR)
      expanded_path.gsub!(File::ALT_SEPARATOR, '/')
    end
    while expanded_path.include?('//')
      expanded_path = expanded_path.gsub('//', '/')
    end

    if expanded_path != "/"
      expanded_path.split('/').each do |path_token|
        if path_token == '..'
          if expand_path_array.size > 1
            expand_path_array.pop
          end
        elsif path_token == '.'
          # nothing to do.
        else
          expand_path_array << path_token
        end
      end

      expanded_path = expand_path_array.join("/")
      if expanded_path.empty?
        expanded_path = '/'
      end
    end
    if drive_prefix.empty?
      expanded_path
    else
      drive_prefix + expanded_path.gsub("/", File::ALT_SEPARATOR)
    end
  end

  class << self
    alias expand expand_path
  end

  private
  def self.concat_path(path, base_path)
    if path[0] == "/" || path[1] == ':' # Windows root!
      expanded_path = path
    elsif path[0] == "~"
      if (path[1] == "/" || path[1] == nil)
        dir = path[1, path.size]
        home_dir = _gethome

        unless home_dir
          raise ArgumentError, "couldn't find HOME environment -- expanding '~'"
        end

        expanded_path = home_dir
        expanded_path += dir if dir
        expanded_path += "/"
      else
        splitted_path = path.split("/")
        user = splitted_path[0][1, splitted_path[0].size]
        dir = "/" + splitted_path[1, splitted_path.size].join("/")

        home_dir = _gethome(user)

        unless home_dir
          raise ArgumentError, "user \#{user} doesn't exist"
        end

        expanded_path = home_dir
        expanded_path += dir if dir
        expanded_path += "/"
      end
    else
      expanded_path = concat_path(base_path, _getwd)
      expanded_path += "/" + path
    end

    expanded_path
  end
end
