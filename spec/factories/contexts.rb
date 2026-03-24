# frozen_string_literal: true

FactoryBot.define do
  factory :context do
    user { custom_create(:user) }
    sequence(:name) { |n| "Scenario #{n}" }
    description { "Scenario planning context" }
    main { false }
    cloned_at { nil }
    archived_at { nil }

    trait :main do
      name { "Main" }
      main { true }
    end
  end
end

# == Schema Information
#
# Table name: contexts
# Database name: primary
#
#  id                :bigint           not null, primary key
#  archived_at       :datetime
#  cloned_at         :datetime
#  description       :text
#  main              :boolean          default(FALSE), not null
#  name              :string           not null, uniquely indexed => [user_id]
#  scenario_key      :string           indexed
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  source_context_id :bigint           indexed
#  user_id           :bigint           not null, uniquely indexed => [name], indexed, uniquely indexed
#
# Indexes
#
#  index_contexts_on_scenario_key             (scenario_key)
#  index_contexts_on_source_context_id        (source_context_id)
#  index_contexts_on_user_and_name            (user_id,name) UNIQUE
#  index_contexts_on_user_id                  (user_id)
#  index_contexts_on_user_id_where_main_true  (user_id) UNIQUE WHERE (main = true)
#
# Foreign Keys
#
#  fk_rails_...  (source_context_id => contexts.id)
#  fk_rails_...  (user_id => users.id)
#
