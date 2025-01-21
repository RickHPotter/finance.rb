# frozen_string_literal: true

# CardTransaction Migration
class CreateCardTransactions < ActiveRecord::Migration[7.1]
  def change
    create_table :card_transactions do |t|
      t.string :description, null: false
      t.text :comment
      t.date :date, null: false
      t.integer :month, null: false
      t.integer :year, null: false
      t.integer :starting_price, null: false
      t.integer :price, null: false
      t.boolean :paid, default: false
      t.integer :card_installments_count, default: 0, null: false

      t.references :user, null: false, foreign_key: true
      t.references :user_card, null: false, foreign_key: true
      t.references :advance_cash_transaction, foreign_key: { to_table: :cash_transactions }

      t.timestamps
    end
  end
end
