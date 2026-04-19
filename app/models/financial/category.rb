# == Schema Information
#
# Table name: categories
#
#  id         :uuid             not null, primary key
#  name       :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  parent_id  :uuid
#  user_id    :uuid             not null
#
# Indexes
#
#  index_categories_on_parent_id  (parent_id)
#  index_categories_on_user_id    (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (parent_id => categories.id)
#  fk_rails_...  (user_id => users.id)
#
module Financial
  class Category < ApplicationRecord
    belongs_to :user
    belongs_to :parent, class_name: "Financial::Category", optional: true

    has_many :children, class_name: "Financial::Category", foreign_key: :parent_id, dependent: :destroy
    has_many :transactions, class_name: "Financial::Transaction"

    validates :name, presence: true
  end
end
