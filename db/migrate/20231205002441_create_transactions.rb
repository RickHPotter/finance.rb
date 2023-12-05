# frozen_string_literal: true

# Migration for Transactions
class CreateTransactions < ActiveRecord::Migration[7.0]
  def change
    create_table :transactions do |t|
      t.string :t_description, null: false
      t.string :t_comment
      t.date :date, null: false
      t.references :user, null: false, foreign_key: true
      t.references :category, null: false, foreign_key: true
      t.decimal :starting_price, null: false
      t.decimal :price, null: false
      t.integer :month, null: false
      t.integer :year, null: false

      t.timestamps
    end
  end
end
