# frozen_string_literal: true

class AddTransactionCountersToFinanceSubscriptions < ActiveRecord::Migration[8.1]
  def up
    add_column :finance_subscriptions, :cash_transactions_count, :integer, default: 0, null: false
    add_column :finance_subscriptions, :card_transactions_count, :integer, default: 0, null: false

    backfill_cash_transactions_count
    backfill_card_transactions_count
  end

  def down
    remove_column :finance_subscriptions, :cash_transactions_count
    remove_column :finance_subscriptions, :card_transactions_count
  end

  private

  def backfill_cash_transactions_count
    execute <<~SQL.squish
      UPDATE finance_subscriptions
      SET cash_transactions_count = counts.cash_transactions_count
      FROM (
        SELECT subscription_id, COUNT(*) AS cash_transactions_count
        FROM cash_transactions
        WHERE subscription_id IS NOT NULL
        GROUP BY subscription_id
      ) AS counts
      WHERE finance_subscriptions.id = counts.subscription_id
    SQL
  end

  def backfill_card_transactions_count
    execute <<~SQL.squish
      UPDATE finance_subscriptions
      SET card_transactions_count = counts.card_transactions_count
      FROM (
        SELECT subscription_id, COUNT(*) AS card_transactions_count
        FROM card_transactions
        WHERE subscription_id IS NOT NULL
        GROUP BY subscription_id
      ) AS counts
      WHERE finance_subscriptions.id = counts.subscription_id
    SQL
  end
end
