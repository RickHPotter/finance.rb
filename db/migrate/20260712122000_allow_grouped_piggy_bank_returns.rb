# frozen_string_literal: true

class AllowGroupedPiggyBankReturns < ActiveRecord::Migration[8.1]
  def change
    remove_index :piggy_banks, :return_cash_transaction_id
    add_index :piggy_banks, :return_cash_transaction_id
  end
end
