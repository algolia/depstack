require 'open-uri'

fast = !ENV['fast'].nil?

puts "Importing Rubygems"
`gem list --remote`.split(/\n/).each do |line|
  name = line.split(/\s/).first
  begin
    Library.load!(:rubygems, name, fast)
  rescue Exception => e
    puts e
  end
end

puts "Importing NPM"
JSON.parse(open('http://isaacs.iriscouch.com/registry/_all_docs').read)['rows'].each do |row|
  name = row['id']
  next if name.blank?
  begin
    Library.load!(:npm, name, fast)
  rescue Exception => e
    puts e
  end
end

puts "Importing PIP"
open("https://pypi.python.org/pypi?:action=index").read.scan(/href="\/pypi\/([^\/]+)\/[^"]+/).each do |s|
  name = s.first
  begin
    Library.load!(:pip, name, fast)
  rescue Exception => e
    puts e
  end
end

puts "Importing Composer"
page = 1
loop do
  doc = Nokogiri::HTML(open("https://packagist.org/packages/?page=#{page}").read)
  (doc / 'h1 a').each do |a|
    name = a.text()
    next if name == 'Packagist'
    begin
      Library.load!(:composer, name, fast)
    rescue Exception => e
      puts e
    end
  end
  next_link = (doc / 'nav a').last
  break if next_link.text() != 'Next'
  page += 1
end
