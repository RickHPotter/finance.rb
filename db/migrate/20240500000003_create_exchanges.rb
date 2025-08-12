# frozen_string_literal: true

# Exchange Migration
class CreateExchanges < ActiveRecord::Migration[8.0]
  def change
    create_table :exchanges do |t|
      t.string :bound_type, null: false, default: :standalone
      t.integer :exchange_type, null: false, default: 0
      t.integer :number, default: 1, null: false
      t.integer :starting_price, null: false
      t.integer :price, null: false
      t.integer :exchanges_count, default: 0, null: false

      t.references :entity_transaction, null: false, foreign_key: true
      t.references :cash_transaction, null: true, foreign_key: true

      t.timestamps
    end
  end
end
