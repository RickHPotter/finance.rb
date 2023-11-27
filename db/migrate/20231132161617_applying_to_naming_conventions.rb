# frozen_string_literal: true

# Migration to fix some sus naming choices
class ApplyingToNamingConventions < ActiveRecord::Migration[7.0]
  def change
    rename_column :user_cards, :card_name, :user_card_name
    rename_column :categories, :description, :category_name
    rename_column :card_transactions, :description, :ct_description
    rename_column :card_transactions, :comment, :ct_comment
  end
end
