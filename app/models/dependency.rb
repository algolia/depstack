class Dependency < ActiveRecord::Base

  belongs_to :source, class_name: 'Library'
  belongs_to :destination, class_name: 'Library'

  as_enum :environment, [:runtime, :test, :development]
end
