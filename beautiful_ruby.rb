require 'fileutils'
require 'tempfile'

def remove_leading_whitespace line
  return nil if line.nil?
  index = line.index /[^\s]/
  index ? line[index..-1] : nil
end

def remove_comments line
  return nil if line.nil?
  index = line.index /#/
  index ? line[0...index] : line
end

def remove_trailing_whitespace line
  return nil if line.nil?
  rev = line.reverse
  rev = remove_leading_whitespace rev
  rev ? rev.reverse : line
end

def remove_delimited line, char
  return nil if line.nil?
  start = line.index /#{char}/
  return line if start.nil?
  temp = line.dup
  temp.slice! start
  stop = temp.index /#{char}/
  return line if stop.nil?
  temp.slice! stop
  temp = temp[0...start] + temp[stop..-1]
  remove_delimited (temp), char
end

def remove_delimited_quotes line, char
  return nil if line.nil?
  start = line.index /([^\\]|^)#{char}/
  if start == 0
    start = -1
  end
  return line if start.nil?
  temp = line.dup
  temp.slice! start+1
  stop = temp.index /([^\\]|^)#{char}/
  return line if stop.nil?
  temp.slice! stop+1
  next_string = ""
  next_string = temp[0..start] if start > 0
  next_string += temp[(stop+1)..-1]
  remove_quotes next_string
end


def remove_quotes line
  return nil if line.nil?
  start_double = line.index /([^\\]|^)"/
  start_single = line.index /([^\\]|^)'/
  if start_double.nil?
    temp = remove_delimited_quotes line, "'"
  elsif start_single.nil? || start_double < start_single
    temp = remove_delimited_quotes line, '"'
  else
    temp = remove_delimited_quotes line, "'"
  end
  temp
end

def remove_regex line
  remove_delimited line, '/'
end

if ARGV.empty?
  files = Dir["./*.rb"]
else
  files = ARGV
end
TAB = "  "
puts files
files.each do |filename|
  t_file = Tempfile.new(filename + "_temp.rb")
  file = File.open(filename, "r+")
  indent = 0
  file.each_line do |line|
    line = remove_leading_whitespace line
    if line.nil?
      t_file.print "\n"
      next
    end
    no_regex = remove_regex line
    no_quotes = remove_quotes no_regex
    no_comments = remove_comments no_quotes
    if no_comments.nil?
      indent.times do
        t_file.print TAB
      end
      t_file.print line
      t_file.print "\n"
      next
    end
    begins = no_comments.scan(/^begin\b/).count
    catches = no_comments.scan(/^catch\b/).count
    ensures = no_comments.scan(/^ensure\b/).count
    defs = no_comments.scan(/^def\b/).count
    left_braces = no_comments.scan(/{/).count
    ends = no_comments.scan(/\bend\b/).count
    right_braces = no_comments.scan(/}/).count
    ifs = no_comments.scan(/^if\b/).count
    elses = no_comments.scan(/^else\b/).count
    elsifs = no_comments.scan(/^elsif\b/).count
    unlesses = no_comments.scan(/^unless\b/).count
    dos = no_comments.scan(/\bdo\b/).count
    cases = no_comments.scan(/\bcase\b/).count
    whens = no_comments.scan(/^when\b/).count
    classes = no_comments.scan(/^class\b/).count
    modules = no_comments.scan(/^module\b/).count
    if left_braces > 0
      indent += right_braces
    end
    if classes > 0 || modules > 0 || dos > 0 || defs > 0 || ifs > 0 || elses > 0 || elsifs > 0 || unlesses > 0
      indent += ends
    end
    if begins > 0
      indent += catches + ensures
    end
    indent -= catches + ensures + ends + right_braces + elses + elsifs + whens

    indent.times do
      t_file.print TAB
    end

    if left_braces > 0
      indent -= right_braces
    end
    if classes > 0 || modules > 0 || dos > 0 || defs > 0 || ifs > 0 || elses > 0 || elsifs > 0 || unlesses > 0
      indent -= ends
    end
    indent += begins + catches + ensures + unlesses + defs + left_braces + ifs + cases + dos + elses + elsifs + whens + classes + modules
    line = remove_trailing_whitespace line
    t_file.print line
    t_file.print "\n"
    indent = 0 if indent < 0
  end
  t_file.close
  FileUtils.mv(t_file.path, filename)
end
