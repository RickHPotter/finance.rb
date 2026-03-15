# frozen_string_literal: true

class AddSubscriptionToTransactions < ActiveRecord::Migration[8.0]
  def change
    add_reference :cash_transactions, :subscription, foreign_key: { to_table: :finance_subscriptions }
    add_reference :card_transactions, :subscription, foreign_key: { to_table: :finance_subscriptions }
  end
end
