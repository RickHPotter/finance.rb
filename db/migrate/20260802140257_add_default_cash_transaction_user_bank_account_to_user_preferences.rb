# frozen_string_literal: true

class AddDefaultCashTransactionUserBankAccountToUserPreferences < ActiveRecord::Migration[8.1]
  def change
    add_column :user_preferences, :default_cash_transaction_user_bank_account_id, :integer
  end
end
