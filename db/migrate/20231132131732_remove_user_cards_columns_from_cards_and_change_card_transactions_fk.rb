# frozen_string_literal: true

# Migration for remodelling Card now that there is a UserCard table
class RemoveUserCardsColumnsFromCardsAndChangeCardTransactionsFk < ActiveRecord::Migration[7.0]
  def change
    return unless table_exists? :cards

    remove_column :cards, :due_date, :date if column_exists? :cards, :due_date
    remove_column :cards, :min_spend, :decimal if column_exists? :cards, :min_spend
    remove_column :cards, :credit_limit, :decimal if column_exists? :cards, :credit_limit
    remove_column :cards, :active, :boolean if column_exists? :cards, :active

    return unless table_exists? :card_transactions
    return unless column_exists? :card_transactions, :card_id

    remove_column :card_transactions, :card_id, :integer
    add_column :card_transactions, :card_id, :integer
    add_foreign_key :card_transactions, :user_cards, column: :card_id
  end
end
