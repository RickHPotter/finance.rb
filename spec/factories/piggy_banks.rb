# frozen_string_literal: true

FactoryBot.define do
  factory :piggy_bank do
    source_cash_transaction { association :cash_transaction }
    return_date { 3.months.from_now }
    return_price { source_cash_transaction.price.to_i.abs }
  end
end

# == Schema Information
#
# Table name: piggy_banks
# Database name: primary
#
#  id                         :bigint           not null, primary key
#  return_date                :datetime         not null
#  return_price               :integer          not null
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#  return_cash_transaction_id :bigint           indexed
#  source_cash_transaction_id :bigint           not null, uniquely indexed
#
# Indexes
#
#  index_piggy_banks_on_return_cash_transaction_id  (return_cash_transaction_id)
#  index_piggy_banks_on_source_cash_transaction_id  (source_cash_transaction_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (return_cash_transaction_id => cash_transactions.id)
#  fk_rails_...  (source_cash_transaction_id => cash_transactions.id)
#
