# frozen_string_literal: true

# Migration to pair User to other tables
class AddUserAsFk < ActiveRecord::Migration[7.0]
  def change
    add_column :categories, :user_id, :integer
    add_column :entities, :user_id, :integer
    add_column :card_transactions, :user_id, :integer

    add_foreign_key :categories, :users
    add_foreign_key :entities, :users
    add_foreign_key :card_transactions, :users
  end
end
