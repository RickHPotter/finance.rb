# frozen_string_literal: true

# Exchange Migration
class CreateExchanges < ActiveRecord::Migration[7.1]
  def change
    create_table :exchanges do |t|
      t.integer :exchange_type, null: false, default: 0
      t.decimal :amount_to_be_returned, null: false
      t.decimal :amount_returned, null: false

      t.references :transaction_entity, null: false, foreign_key: true

      t.timestamps
    end
  end
end
