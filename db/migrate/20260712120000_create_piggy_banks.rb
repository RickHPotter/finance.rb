# frozen_string_literal: true

class CreatePiggyBanks < ActiveRecord::Migration[8.1]
  def change
    create_table :piggy_banks do |t|
      t.references :source_cash_transaction, null: false, foreign_key: { to_table: :cash_transactions }, index: { unique: true }
      t.references :return_cash_transaction, null: true, foreign_key: { to_table: :cash_transactions }, index: { unique: true }
      t.datetime :return_date, null: false
      t.integer :return_price, null: false

      t.timestamps
    end

    add_check_constraint :piggy_banks, "return_price > 0", name: "piggy_banks_return_price_positive"
  end
end
