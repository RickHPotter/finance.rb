# frozen_string_literal: true

class UpdateUserPreferencesFields < ActiveRecord::Migration[8.0]
  def change
    remove_column :user_preferences, :page_density, :string, default: "comfortable", null: false
    remove_column :user_preferences, :date_time_presentation, :string, default: "relative", null: false
    remove_column :user_preferences, :default_account_id, :integer
    remove_column :user_preferences, :default_card_id, :integer

    add_column :user_preferences, :default_card_transaction_date_order, :string, default: "card_installment_date", null: false
    add_column :user_preferences, :default_cash_transaction_date_order, :string, default: "cash_transaction_date", null: false
  end
end
