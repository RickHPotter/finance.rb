# frozen_string_literal: true

# CardTransaction/MoneyTransaction Migration
class CreateInstallments < ActiveRecord::Migration[7.1]
  def change
    create_table :installments do |t|
      t.decimal :starting_price, null: false
      t.decimal :price, null: false
      t.integer :number, null: false
      t.integer :month, null: false
      t.integer :year, null: false
      t.integer :card_transactions_count, default: 0, null: false

      t.references :card_transaction, null: false, foreign_key: true
      t.references :money_transaction, null: false, foreign_key: true

      t.timestamps
    end

    add_index :installments,
              %i[card_transaction_id money_transaction_id number],
              unique: true,
              name: "index_card_transactions_money_transaction_on_composite_key"
  end
end
