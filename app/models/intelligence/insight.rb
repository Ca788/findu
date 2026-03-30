# == Schema Information
#
# Table name: insights
#
#  id              :uuid             not null, primary key
#  content         :text
#  metadata        :jsonb
#  reference_type  :string           not null
#  severity        :string
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  organization_id :uuid             not null
#  reference_id    :uuid
#  user_id         :uuid             not null
#
# Indexes
#
#  index_insights_on_organization_id  (organization_id)
#  index_insights_on_reference_type   (reference_type)
#  index_insights_on_user_id          (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (organization_id => organizations.id)
#  fk_rails_...  (user_id => users.id)
#
module Intelligence
  class Insight < ApplicationRecord
    belongs_to :organization
    belongs_to :user

    validates :reference_type, presence: true
  end
end
