# == Schema Information
#
# Table name: users
#
#  id              :uuid             not null, primary key
#  deleted_at      :datetime
#  email           :string           not null
#  name            :string           not null
#  password_digest :string
#  phone           :string
#  settings        :jsonb
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
# Indexes
#
#  index_users_on_email  (email) UNIQUE
#
class User < ApplicationRecord
  has_secure_password

  has_many :artifacts, dependent: :destroy
  has_many :categories, class_name: "Financial::Category", dependent: :destroy
  has_many :transactions, class_name: "Financial::Transaction", dependent: :destroy
  has_many :budgets, class_name: "Financial::Budget", dependent: :destroy
  has_many :insights, class_name: "Intelligence::Insight", dependent: :destroy

  validates :name, presence: true
  validates :email, presence: true, uniqueness: true
end
