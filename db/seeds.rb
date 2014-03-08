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
 next_link = (doc / 'nav a').last
 break if next_link.text() != 'Next'
 Parallel.each((page..(page + nb_threads)).to_a, in_processes: nb_threads) do |p|
   @reconnected ||= Library.connection.reconnect! || true
   doc = Nokogiri::HTML(open("https://packagist.org/packages/?page=#{p}").read)
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
 end
 page += nb_threads
end

puts "Importing Go"
page = 1
loop do
 doc = Nokogiri::HTML(open("http://go-search.org/search?q=&p=#{page}").read)
 break if (doc / '.info').empty?
 Parallel.each((page..(page + nb_threads)).to_a, in_processes: nb_threads) do |p|
   @reconnected ||= Library.connection.reconnect! || true
   doc = Nokogiri::HTML(open("http://go-search.org/search?q=&p=#{p}").read)
   (doc / '.info').each do |info|
     name = (info / 'a')[0].text
     begin
       puts name
       Library.load!(:go, name, fast)
     rescue Exception => e
       puts e
     end
   end
 end
 page += nb_threads
end

puts "Importing Julia libraries"
doc = Nokogiri::HTML(open("http://docs.julialang.org/en/release-0.1/packages/packagelist/#available-packages.json").read)
doc.search('.section').first.search('.section').each do |lib|
  content = lib.xpath(".//blockquote//div//p")
  name = lib.search('.reference')[0].text
  puts name
  library = Library.find_or_initialize_by(manager_cd: Library.managers["julia"], name: name)
  library.repository_uri = lib.search('.reference').first["href"]
  library.description = content[1].text
  library.platform = 'julia'
  library.downloads = 0
  library.homepage_uri = nil
  begin
    library.save!
  rescue Exception => e
    puts e
  end
end
puts "Importing Julia dependencies"
doc.search('.section').first.search('.section').each do |lib|
  name = lib.search('.reference')[0].text
  library = Library.find_or_initialize_by(manager_cd: Library.managers["julia"], name: name)
  library.dependencies = []
  lib.search("pre").each do |deps|
    deps.content.split(/\n/).each do |dep|
      dep_data = dep.split(/ +/, 2)
      dependency_library = Library.find_or_initialize_by(manager_cd: Library.managers["julia"], name: dep_data[0])
      dependency_library.save! #For missing lib
      library.dependencies.create(destination_id: dependency_library.id, environment: nil, requirement: dep_data[1]) rescue nil
    end
  end
  library.save!
end

puts "Importing Maven libraries"
def extract_pom(doc)
  name = doc.xpath("//project//groupid").text + doc.xpath("//project//artifactid").text
  p name
  library = Library.find_or_initialize_by(manager_cd: Library.managers["maven"], name: name)
  library.description = doc.xpath("//project//description").text rescue nil
  library.repository_uri = doc.xpath("//project//scm//url").text rescue nil
  library.downloads = 0
  library.platform = "java"
  library.dependencies = []
  # Dependencies
  doc.search("dependency").each do |dep|
    name =  dep.xpath(".//groupid").text + dep.xpath(".//artifactid").text
    dependency = Library.find_or_initialize_by(manager_cd: Library.managers["maven"], name: name)
    dependency.save! #For missing lib
    library.dependencies.create(destination_id: dependency.id, environnment: dep.xpath(".//scope") ? dep.xpath(".//scope").text : nil, requirement: dep.xpath(".//version").text) rescue nil #TODO parse properties
  end
  library.save!
end

def parse_maven(json)
  json["response"]["docs"].each do |doc|
    puts ("http://search.maven.org/" + "remotecontent?filepath=" + doc["g"].split(".").join('/') + "/" + doc["a"] + "/" + doc["latestVersion"] + "/" + doc["a"] + "-" + doc["latestVersion"] + ".pom")
    extract_pom(Nokogiri::HTML(open("http://search.maven.org/" + "remotecontent?filepath=" + doc["g"].split(".").join('/') + "/" + doc["a"] + "/" + doc["latestVersion"] + "/" + doc["a"] + "-" + doc["latestVersion"] + ".pom")))
  end
end

def explore_maven(doc)
  doc.search('a').each do |link|
    next if link.text == "../"
    if link['href'].start_with?("#browse") && link['href'] != "#browse" && link['href'] != "#browse%7C47"
      explore_maven(Nokogiri::HTML(open("http://search.maven.org/" + link['href']).read))
    elsif link['href'].end_with?("pom")
      extract_pom(Nokogiri::HTML(open("http://search.maven.org/" + link['href']).read))
    end
  end
end
doc = JSON.parse(open('http://search.maven.org/solrsearch/select?q=*:*&rows=200&wt=json').read)
parse_maven(doc)

puts "Importing APM"
Parallel.each(JSON.parse(open('https://atom.io/api/packages').read), in_processes: nb_threads) do |package|
  @reconnected ||= Library.connection.reconnect! || true
  name = package['name']
  next if name.blank?
  begin
   puts name
   Library.load!(:apm, name, fast)
  rescue Exception => e
   puts e
  end
end
