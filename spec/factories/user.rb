# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    organization
    name { Faker::Name.name }
    email { Faker::Internet.email }
    password { "password123" }
    password_confirmation { "password123" }
  end
end
