# frozen_string_literal: true

FactoryBot.define do
  factory :user_preference do
    user { nil }
    theme { "MyString" }
    landing_page { "MyString" }
    active_context_id { 1 }
    page_density { "MyString" }
    date_time_presentation { "MyString" }
    default_account_id { 1 }
    default_card_id { 1 }
  end
end

# == Schema Information
#
# Table name: user_preferences
# Database name: primary
#
#  id                                            :bigint           not null, primary key
#  default_card_transaction_date_order           :string           default("card_installment_date"), not null
#  default_cash_transaction_date_order           :string           default("cash_installment_date"), not null
#  exchange_default_bound_type                   :string           default("standalone"), not null
#  landing_page                                  :string           default("cash_transactions"), not null
#  page_density                                  :string           default("default"), not null
#  row_color_mode                                :string           default("row_coloured"), not null
#  theme                                         :string           default("light"), not null
#  created_at                                    :datetime         not null
#  updated_at                                    :datetime         not null
#  active_context_id                             :integer
#  default_cash_transaction_user_bank_account_id :integer
#  user_id                                       :bigint           not null, uniquely indexed
#
# Indexes
#
#  index_user_preferences_on_user_id  (user_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
