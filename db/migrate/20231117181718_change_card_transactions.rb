# frozen_string_literal: true

# CardTransaction Changes Migration
class ChangeCardTransactions < ActiveRecord::Migration[7.0]
  def change
    return unless table_exists? :card_transactions

    if column_exists? :card_transactions, :installments_number
      remove_column :card_transactions, :installments_number
      add_column :card_transactions, :installments_count, :integer, default: 0, null: false
    end

    return unless column_exists? :card_transactions, :installments

    remove_column :card_transactions, :installments
    add_reference :card_transactions, :installment, null: false, foreign_key: true
  end
end
