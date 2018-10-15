##
# Original from https://github.com/defunkt/colored/blob/master/lib/colored.rb
#
# Copyright (c) 2010 Chris Wanstrath
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# Software), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED AS IS, WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

##
# cute.
#
#   >> "this is red".red
#
#   >> "this is red with a blue background (read: ugly)".red_on_blue
#
#   >> "this is red with an underline".red.underline
#
#   >> "this is really bold and really blue".bold.blue
#
#   >> Colored.red "This is red" # but this part is mostly untested
module Colored
  extend self

  COLORS = {
    'black'   => 30,
    'red'     => 31,
    'green'   => 32,
    'yellow'  => 33,
    'blue'    => 34,
    'magenta' => 35,
    'cyan'    => 36,
    'white'   => 37
  }

  EXTRAS = {
    'clear'     => 0,
    'bold'      => 1,
    'underline' => 4,
    'reversed'  => 7
  }

  COLORS.each do |color, value|
    define_method(color) do
      colorize(self, :foreground => color)
    end

    define_method("on_#{color}") do
      colorize(self, :background => color)
    end

    COLORS.each do |highlight, value|
      next if color == highlight
      define_method("#{color}_on_#{highlight}") do
        colorize(self, :foreground => color, :background => highlight)
      end
    end
  end

  EXTRAS.each do |extra, value|
    next if extra == 'clear'
    define_method(extra) do
      colorize(self, :extra => extra)
    end
  end

  ## Standard mruby has no regexp. Skip.
  # define_method(:to_eol) do
  #   tmp = sub(/^(\e\[[\[\e0-9;m]+m)/, "\\1\e[2K")
  #   if tmp == self
  #     return "\e[2K" << self
  #   end
  #   tmp
  # end

  def colorize(string, options = {})
    colored = [color(options[:foreground]), color("on_#{options[:background]}"), extra(options[:extra])].compact.join('')
    colored << string
    colored << extra(:clear)
  end

  def colors
    @@colors ||= COLORS.keys.sort
  end

  def extra(extra_name)
    extra_name = extra_name.to_s
    "\e[#{EXTRAS[extra_name]}m" if EXTRAS[extra_name]
  end

  def color(color_name)
    background = color_name.to_s.include? 'on_'
    color_name = color_name.to_s.sub('on_', '')
    return unless color_name && COLORS[color_name]
    "\e[#{COLORS[color_name] + (background ? 10 : 0)}m"
  end
end unless Object.const_defined? :Colored

class String
  include Colored
end
