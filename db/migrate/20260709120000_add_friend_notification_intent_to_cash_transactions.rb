# frozen_string_literal: true

class AddFriendNotificationIntentToCashTransactions < ActiveRecord::Migration[8.1]
  def change
    add_column :cash_transactions, :friend_notification_intent, :string

    reversible do |dir|
      dir.up { backfill_friend_notification_intent }
    end
  end

  private

  def backfill_friend_notification_intent
    CashTransaction.reset_column_information

    exchange_source_scope.find_each do |cash_transaction|
      intent = cash_transaction.effective_friend_notification_intent.presence || "loan"
      next unless intent.in?(CashTransaction::FRIEND_NOTIFICATION_INTENTS)

      cash_transaction.update_columns(friend_notification_intent: intent)
    end

    CashTransaction.where.not(id: exchange_source_scope.select(:id)).where.not(friend_notification_intent: nil).update_all(friend_notification_intent: nil)
  end

  def exchange_source_scope
    CashTransaction.joins(:categories).where(categories: { category_name: "EXCHANGE" }).distinct
  end
end
