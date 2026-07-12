# frozen_string_literal: true

class AddLoanReturnPercentageToEntityTransactions < ActiveRecord::Migration[8.1]
  def change
    add_column :entity_transactions, :loan_return_percentage, :decimal, precision: 10, scale: 4, null: false, default: 100
  end
end
