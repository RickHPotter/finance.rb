# frozen_string_literal: true

# MoneyTransaction Migration
class CreateMoneyTransactions < ActiveRecord::Migration[7.1]
  def change
    create_table :money_transactions do |t|
      t.string :mt_description, null: false
      t.text :mt_comment
      t.date :date, null: false
      t.integer :month, null: false
      t.integer :year, null: false
      t.decimal :starting_price, null: false
      t.decimal :price, null: false
      t.string :money_transaction_type, null: true

      t.references :user, null: false, foreign_key: true
      t.references :user_card, null: true, foreign_key: true
      t.references :user_bank_account, null: true, foreign_key: true

      t.timestamps
    end
  end
end
