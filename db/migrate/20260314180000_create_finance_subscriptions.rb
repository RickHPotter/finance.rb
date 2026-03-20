# frozen_string_literal: true

class CreateFinanceSubscriptions < ActiveRecord::Migration[8.0]
  def change
    create_table :finance_subscriptions do |t|
      t.references :user, null: false, foreign_key: true
      t.string :description, null: false
      t.integer :price, null: false, default: 0
      t.text :comment
      t.string :status, null: false, default: "active"
      t.integer :cash_transactions_count, null: false, default: 0
      t.integer :card_transactions_count, null: false, default: 0

      t.timestamps
    end

    add_index :finance_subscriptions, :status

    add_reference :cash_transactions, :subscription, foreign_key: { to_table: :finance_subscriptions }
    add_reference :card_transactions, :subscription, foreign_key: { to_table: :finance_subscriptions }
  end
end
