namespace :depstack do

  task :learn => :environment do
    training = {}
    ('a'..'z').each do |letter|
      doc = Nokogiri::HTML(File.read File.join(Rails.root, 'db', 'categories', 'train', "#{letter}.html"))
      (doc / '.group_items li').each do |li|
        categories = (li / 'ul.handles li a').map { |a| a.text }
        next if categories.empty?
        text = (li / 'span.description').text
        categories.each do |cat|
          training[cat] ||= []
          training[cat] << text
        end
      end
    end
    File.open(File.join(Rails.root, 'db', 'categories_model.json'), 'w') do |f|
      f << training.to_json
    end
  end

end