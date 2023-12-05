# frozen_string_literal: true

# Migration for Card to include Bank
class AddBankToCardAndUserBankAccountToTransaction < ActiveRecord::Migration[7.0]
  def change
    unless column_exists?(:cards, :bank_id)
      add_column :cards, :bank_id, :integer, null: false
      add_foreign_key :cards, :banks, column: :bank_id
    end

    return unless table_exists?(:user_bank_accounts)

    add_column :transactions, :user_bank_account_id, :integer, null: false
    add_foreign_key :transactions, :user_bank_accounts, column: :user_bank_account_id
  end
end
