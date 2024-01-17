# frozen_string_literal: true

# Exchange Migration
class CreateExchanges < ActiveRecord::Migration[7.1]
  def change
    create_table :exchanges do |t|
      t.integer :exchange_type, null: false, default: 0
      t.integer :number, default: 1, null: false
      t.decimal :amount_to_be_returned, null: false
      t.decimal :amount_returned, null: false

      t.references :entity_transaction, null: false, foreign_key: true
      t.references :money_transaction, null: true, foreign_key: true

      t.timestamps
    end
  end
end
