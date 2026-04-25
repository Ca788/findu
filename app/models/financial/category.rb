# == Schema Information
#
# Table name: categories
#
#  id         :uuid             not null, primary key
#  name       :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  user_id    :uuid             not null
#
# Indexes
#
#  index_categories_on_user_id  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
module Financial
  class Category < ApplicationRecord
    belongs_to :user

    has_many :transactions, class_name: "Financial::Transaction"

    validates :name, presence: true
  end
end
