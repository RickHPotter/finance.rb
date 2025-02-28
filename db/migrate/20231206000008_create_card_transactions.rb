# frozen_string_literal: true

# CardTransaction Migration
class CreateCardTransactions < ActiveRecord::Migration[8.0]
  def change
    create_table :card_transactions do |t|
      t.string :description, null: false
      t.text :comment
      t.datetime :date, null: false
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

      execute "CREATE EXTENSION IF NOT EXISTS pg_trgm;"

      t.index [ :description ], name: "idx_card_transactions_description_trgm", opclass: :gin_trgm_ops, using: :gin
      t.index [ :price ],       name: "idx_card_transactions_price"
    end
  end
end
