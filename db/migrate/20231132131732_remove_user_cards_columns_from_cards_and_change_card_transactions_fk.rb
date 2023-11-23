# frozen_string_literal: true

# Migration for remodelling Card now that there is a UserCard table
class RemoveUserCardsColumnsFromCardsAndChangeCardTransactionsFk < ActiveRecord::Migration[7.0]
  def change
    remove_column :cards, :due_date, :date
    remove_column :cards, :min_spend, :decimal
    remove_column :cards, :credit_limit, :decimal
    remove_column :cards, :active, :boolean

    remove_column :card_transactions, :card_id, :integer
    add_column :card_transactions, :card_id, :integer
    add_foreign_key :card_transactions, :user_cards, column: :card_id
  end
end
