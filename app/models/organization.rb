# == Schema Information
#
# Table name: organizations
#
#  id         :uuid             not null, primary key
#  name       :string           not null
#  plan       :string
#  settings   :jsonb
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
class Organization < ApplicationRecord
  has_many :users, dependent: :destroy
  has_many :artifacts, dependent: :destroy
  has_many :transactions, class_name: "Financial::Transaction", dependent: :destroy
  has_many :categories, class_name: "Financial::Category", dependent: :destroy
  has_many :budgets, class_name: "Financial::Budget", dependent: :destroy
  has_many :insights, class_name: "Intelligence::Insight", dependent: :destroy

  validates :name, presence: true
end
