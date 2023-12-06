# frozen_string_literal: true

# Migration for creating Investments
class CreateInvestments < ActiveRecord::Migration[7.0]
  def change
    create_table :investments do |t|
      t.decimal :price, null: false
      t.date :date, null: false
      t.integer :month, null: false
      t.integer :year, null: false
      t.references :user, null: false, foreign_key: true
      t.references :category, null: false, foreign_key: true
      t.references :user_bank_account, null: false, foreign_key: true
      t.references :transaction, null: false, foreign_key: true

      t.timestamps
    end
  end
end
