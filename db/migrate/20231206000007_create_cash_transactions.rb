# frozen_string_literal: true

# CashTransaction Migration
class CreateCashTransactions < ActiveRecord::Migration[7.1]
  def change
    create_table :cash_transactions do |t|
      t.string :description, null: false
      t.text :comment
      t.date :date, null: false
      t.integer :month, null: false
      t.integer :year, null: false
      t.integer :starting_price, null: false
      t.integer :price, null: false
      t.boolean :paid, default: false
      t.integer :installments_count, default: 0, null: false
      t.string :cash_transaction_type, null: true

      t.references :user, null: false, foreign_key: true
      t.references :user_card, null: true, foreign_key: true
      t.references :user_bank_account, null: true, foreign_key: true

      t.timestamps
    end
  end
end
