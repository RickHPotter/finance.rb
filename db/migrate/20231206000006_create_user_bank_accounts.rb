# frozen_string_literal: true

# UserBankAccount Migration
class CreateUserBankAccounts < ActiveRecord::Migration[8.0]
  def change
    create_table :user_bank_accounts do |t|
      t.integer :agency_number
      t.integer :account_number
      t.boolean :active, null: false, default: true
      t.integer :balance, null: false, default: 0
      t.integer :cash_transactions_count, null: false, default: 0
      t.integer :cash_transactions_total, null: false, default: 0

      t.references :user, null: false, foreign_key: true
      t.references :bank, null: false, foreign_key: true

      t.timestamps
    end
  end
end
