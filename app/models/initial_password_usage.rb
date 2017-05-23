class InitialPasswordUsage < ApplicationRecord
  belongs_to :user, required: true
  validates :user, uniqueness: true
end
