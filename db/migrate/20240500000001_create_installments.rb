# frozen_string_literal: true

# CardTransaction/CashTransaction Migration
class CreateInstallments < ActiveRecord::Migration[7.1]
  def change
    create_table :installments do |t|
      t.integer :starting_price, null: false
      t.integer :price, null: false
      t.integer :number, null: false
      t.integer :month, null: false
      t.integer :year, null: false
      t.string :installment_type, null: false
      t.integer :card_installments_count, default: 0, null: true
      t.integer :cash_installments_count, default: 0, null: true

      t.references :card_transaction, null: true, foreign_key: true
      t.references :cash_transaction, null: true, foreign_key: true

      t.timestamps
    end
  end
end
