require 'csv'
require 'nokogiri'
require 'optparse'

HEADER_LINE = "folder,favorite,type,name,notes,fields,login_uri,login_username,login_password,login_totp\n".freeze

class PasswordEntry
  attr_accessor :name, :notes, :login_uri, :login_username, :login_password

  def self.from_entry_xml(xml_node)
    node = new
    xml_node.search('title', 'username', 'password', 'url', 'comment').each do |child|
      case child.name
      when 'title'
        node.name = child.text
      when 'username'
        node.login_username = child.text
      when 'password'
        node.login_password = child.text
      when 'url'
        node.login_uri = child.text
      when 'comment'
        node.notes = child.text
      end
    end

    node
  end

  def to_csv_row
    [
      nil, # folder
      nil, # favorite
      nil, # type
      name,
      notes,
      nil, # fields
      login_uri,
      login_username,
      login_password,
      nil, # login_totp
    ].to_csv
  end
end

options = {}
OptionParser.new do |opts|
  opts.banner = 'Usage: converter.rb [options] [inputfile]'

  opts.on('-o FILENAME', 'Output path for the CSV file') do |filename|
    options[:outfile] = filename
  end

  opts.on('-h', '--help', 'Prints this help') do
    puts opts
    exit
  end

end.parse!(ARGV)

infile = ARGV.pop
raise 'No input file specified, run with -h for help.' unless infile

xml_doc = File.open(infile) do |f|
  Nokogiri::XML(f) { |config| config.noblanks }
end

entries = []
xml_doc.root.children.each do |group|
  next unless group.name == 'group'

  group_title = group.search('./title').text
  next unless group_title == 'General' # Skip "backup" top-level group

  group.search('entry').each do |e|
    entries << PasswordEntry.from_entry_xml(e)
  end
end

result_string = HEADER_LINE
entries.each { |entry| result_string += entry.to_csv_row }
if options[:outfile]
  File.open(options[:outfile], 'w') { |f| f.write(result_string) }
else
  puts result_string
end
