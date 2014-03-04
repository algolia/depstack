class User < ActiveRecord::Base

  has_many :votes
  has_many :libraries, through: :votes

  def has_voted?(library)
    votes.where(library_id: library.id).count > 0
  end

end
