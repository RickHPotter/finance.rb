# frozen_string_literal: true

# Investment Migration
class CreateInvestments < ActiveRecord::Migration[8.0]
  def change
    create_table :investments do |t|
      t.string :description, null: true
      t.datetime :date, null: false
      t.integer :month, null: false
      t.integer :year, null: false
      t.integer :price, null: false

      t.references :user, null: false, foreign_key: true
      t.references :user_bank_account, null: false, foreign_key: true
      t.references :cash_transaction, foreign_key: true, null: true

      t.timestamps
    end
  end
end
