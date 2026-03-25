# frozen_string_literal: true

FactoryBot.define do
  factory :subscription do
    user { custom_create(:user) }
    context { user.main_context }
    status { :active }
    description { "ChatGPT Plus" }
    price { 0 }
    comment { "Recurring subscription" }

    trait :finished do
      status { :finished }
    end
  end
end

# == Schema Information
#
# Table name: finance_subscriptions
# Database name: primary
#
#  id                      :bigint           not null, primary key
#  card_transactions_count :integer          default(0), not null
#  cash_transactions_count :integer          default(0), not null
#  comment                 :text
#  description             :string           not null
#  price                   :integer          default(0), not null
#  status                  :string           default("active"), not null, indexed
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  context_id              :bigint           not null, indexed
#  user_id                 :bigint           not null, indexed
#
# Indexes
#
#  index_finance_subscriptions_on_context_id  (context_id)
#  index_finance_subscriptions_on_status      (status)
#  index_finance_subscriptions_on_user_id     (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (context_id => contexts.id)
#  fk_rails_...  (user_id => users.id)
#
