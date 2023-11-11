# frozen_string_literal: true

# Card Transactions Migration
class CreateCardTransactions < ActiveRecord::Migration[7.0]
  def change
    create_table :card_transactions do |t|
      t.date :date, null: false
      t.references :card, null: false, foreign_key: true
      t.string :description, null: false
      t.text :comment
      t.references :category, null: false, foreign_key: true
      t.references :category2, null: true, foreign_key: true
      t.references :entity, null: false, foreign_key: true
      t.decimal :starting_price, null: false
      t.decimal :price, null: false
      t.integer :month, null: false
      t.integer :year, null: false
      t.integer :installments, null: false
      t.integer :installments_number, null: false

      t.timestamps
    end
  end
end
