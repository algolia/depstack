require 'open-uri'

nb_threads = Rails.env.production? ? 16 : 1
fast = !ENV['fast'].nil?

puts "Importing Rubygems"
Parallel.each(`gem list --remote`.split(/\n/), in_processes: nb_threads) do |line|
  @reconnected ||= Library.connection.reconnect! || true
  name = line.split(/\s/).first
  begin
    puts name
    Library.load!(:rubygems, name, fast)
  rescue Exception => e
    puts e
  end
end

puts "Importing NPM"
Parallel.each(JSON.parse(open('http://isaacs.iriscouch.com/registry/_all_docs').read)['rows'], in_processes: nb_threads) do |row|
  @reconnected ||= Library.connection.reconnect! || true
  name = row['id']
  next if name.blank?
  begin
    puts name
    Library.load!(:npm, name, fast)
  rescue Exception => e
    puts e
  end
end

puts "Importing PIP"
Parallel.each(open("https://pypi.python.org/pypi?:action=index").read.scan(/href="\/pypi\/([^\/]+)\/[^"]+/), in_processes: nb_threads) do |s|
  @reconnected ||= Library.connection.reconnect! || true
  name = s.first
  begin
    puts name
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
      puts name
      Library.load!(:composer, name, fast)
    rescue Exception => e
      puts e
    end
  end
  next_link = (doc / 'nav a').last
  break if next_link.text() != 'Next'
  page += 1
end

puts "Importing Go"
page = 1
loop do
  doc = Nokogiri::HTML(open("http://go-search.org/search?q=&p=#{page}").read)
  infos = (doc / '.info')
  break if infos.empty?
  infos.each do |info|
    name = (info / 'a')[0].text
    begin
      puts name
      Library.load!(:go, name, fast)
    rescue Exception => e
      puts e
    end
  end
  page += 1
end
