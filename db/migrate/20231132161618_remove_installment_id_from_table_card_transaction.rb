# frozen_string_literal: true

# Migration for removing unecessary id in CardTransaction for Installment
class RemoveInstallmentIdFromTableCardTransaction < ActiveRecord::Migration[7.0]
  def change
    return unless table_exists? :card_transactions

    return unless column_exists? :card_transactions, :installment_id

    remove_column :card_transactions, :installment_id, :integer
  end
end
