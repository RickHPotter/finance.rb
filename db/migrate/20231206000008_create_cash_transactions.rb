# frozen_string_literal: true

# CashTransaction Migration
class CreateCashTransactions < ActiveRecord::Migration[8.0]
  def change
    return if table_exists?(:cash_transactions)

    create_table :cash_transactions do |t|
      t.string :description, null: false
      t.text :comment
      t.datetime :date, null: false
      t.integer :month, null: false
      t.integer :year, null: false
      t.integer :starting_price, null: false
      t.integer :price, null: false
      t.boolean :paid, default: false
      t.boolean :imported, default: false
      t.string :cash_transaction_type, null: true
      t.integer :cash_installments_count, default: 0, null: false

      t.references :user, null: false, foreign_key: true
      t.references :user_card, null: true, foreign_key: true
      t.references :user_bank_account, null: true, foreign_key: true
      t.references :reference_transactable, null: true, polymorphic: true

      t.timestamps

      t.index %w[reference_transactable_type reference_transactable_id], name: "index_reference_transactable_on_cash_composite_key", unique: true
    end
  end
end
