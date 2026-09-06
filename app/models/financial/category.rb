# == Schema Information
#
# Table name: categories
#
#  id         :uuid             not null, primary key
#  name       :string           not null
#  whatsapp   :string
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
    has_many :receipts, class_name: "Financial::Receipt"

    validates :name, presence: true
    validates :whatsapp, format: { with: /\A\+?\d{8,15}\z/ }, allow_blank: true

    before_validation :normalize_whatsapp

    private

    def normalize_whatsapp
      return if whatsapp.blank?

      self.whatsapp = whatsapp.to_s.gsub(/[^\d+]/, "")
    end
  end
end
