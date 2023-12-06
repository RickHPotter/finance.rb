# frozen_string_literal: true

# Migration to pair User to other tables
class AddUserAsFk < ActiveRecord::Migration[7.0]
  def change
    unless column_exists? :categories, :user_id
      add_column :categories, :user_id, :integer
      add_foreign_key :categories, :users
    end

    unless column_exists? :entities, :user_id
      add_column :entities, :user_id, :integer
      add_foreign_key :entities, :users
    end

    return if column_exists? :card_transactions, :user_id

    add_column :card_transactions, :user_id, :integer
    add_foreign_key :card_transactions, :users
  end
end
