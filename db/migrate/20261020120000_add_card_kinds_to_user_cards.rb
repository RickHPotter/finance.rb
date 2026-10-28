# frozen_string_literal: true

class AddCardKindsToUserCards < ActiveRecord::Migration[8.1]
  def change
    add_column :user_cards, :card_kind, :string, null: false, default: "credit"
    add_reference :user_cards, :user_bank_account, foreign_key: true
    add_check_constraint :user_cards, "card_kind IN ('credit', 'prepaid', 'debit')", name: "user_cards_card_kind_values"

    change_column_null :user_cards, :due_date_day, true
    change_column_null :user_cards, :days_until_due_date, true
    change_column_null :user_cards, :credit_limit, true
    change_column_null :user_cards, :min_spend, true
    change_column_default :user_cards, :due_date_day, from: 1, to: nil
  end
end
