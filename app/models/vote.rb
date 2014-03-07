class Vote < ActiveRecord::Base

  belongs_to :user
  belongs_to :library, counter_cache: :votes_count

end
