# == Schema Information
#
# Table name: budgets
#
#  id              :uuid             not null, primary key
#  deleted_at      :datetime
#  limit_amount    :decimal(10, 2)
#  month           :integer          not null
#  year            :integer          not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  organization_id :uuid             not null
#  user_id         :uuid             not null
#
# Indexes
#
#  index_budgets_on_organization_id             (organization_id)
#  index_budgets_on_user_id                     (user_id)
#  index_budgets_on_user_id_and_month_and_year  (user_id,month,year) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (organization_id => organizations.id)
#  fk_rails_...  (user_id => users.id)
#
module Financial
  class Budget < ApplicationRecord
    belongs_to :organization
    belongs_to :user

    validates :month, presence: true
    validates :year, presence: true
  end
end
