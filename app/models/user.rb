# frozen_string_literal: true

# == Schema Information
#
# Table name: users
#
#  id                     :uuid             not null, primary key
#  deleted_at             :datetime
#  email                  :string           not null
#  encrypted_password     :string           default(""), not null
#  jti                    :string           not null
#  name                   :string           not null
#  phone                  :string
#  reset_password_sent_at :datetime
#  reset_password_token   :string
#  settings               :jsonb
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#
# Indexes
#
#  index_users_on_email                 (email) UNIQUE
#  index_users_on_jti                   (jti) UNIQUE
#  index_users_on_reset_password_token  (reset_password_token) UNIQUE
#
class User < ApplicationRecord
  include Devise::JWT::RevocationStrategies::JTIMatcher

  devise :database_authenticatable,
         :recoverable,
         :validatable,
         :jwt_authenticatable,
         jwt_revocation_strategy: self

  has_many :artifacts, dependent: :destroy
  has_many :categories, class_name: "Financial::Category", dependent: :destroy
  has_many :transactions, class_name: "Financial::Transaction", dependent: :destroy
  has_many :budgets, class_name: "Financial::Budget", dependent: :destroy
  has_many :insights, class_name: "Intelligence::Insight", dependent: :destroy

  validates :name, presence: true
end
