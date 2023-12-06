# frozen_string_literal: true

# Migration to fix some sus naming choices
class ApplyingToNamingConventions < ActiveRecord::Migration[7.0]
  def change
    rename_column :user_cards, :card_name, :user_card_name if column_exists?(:user_cards, :card_name)
    rename_column :categories, :description, :category_name if column_exists?(:categories, :description)
    rename_column :card_transactions, :description, :ct_description if column_exists?(:card_transactions, :description)
    rename_column :card_transactions, :comment, :ct_comment if column_exists?(:card_transactions, :comment)
  end
end
