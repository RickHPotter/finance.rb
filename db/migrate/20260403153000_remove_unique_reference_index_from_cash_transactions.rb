# frozen_string_literal: true

class RemoveUniqueReferenceIndexFromCashTransactions < ActiveRecord::Migration[8.1]
  def up
    remove_index :cash_transactions, name: "index_reference_transactable_on_cash_composite_key", if_exists: true
  end

  def down
    add_index :cash_transactions,
              %w[reference_transactable_type reference_transactable_id],
              name: "index_reference_transactable_on_cash_composite_key",
              unique: true
  end
end
