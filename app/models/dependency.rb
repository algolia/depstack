class Dependency < ActiveRecord::Base

  belongs_to :library
  belongs_to :project

end
