# == Schema Information
#
# Table name: users
#
#  id              :uuid             not null, primary key
#  deleted_at      :datetime
#  email           :string           not null
#  name            :string           not null
#  phone           :string
#  role            :string
#  settings        :jsonb
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  organization_id :uuid             not null
#
# Indexes
#
#  index_users_on_organization_id            (organization_id)
#  index_users_on_organization_id_and_email  (organization_id,email) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (organization_id => organizations.id)
#
class User < ApplicationRecord
  belongs_to :organization

  has_many :artifacts, dependent: :destroy
  has_many :transactions, class_name: "Financial::Transaction", dependent: :destroy
  has_many :budgets, class_name: "Financial::Budget", dependent: :destroy
  has_many :insights, class_name: "Intelligence::Insight", dependent: :destroy

  validates :name, presence: true
  validates :email, presence: true
end
