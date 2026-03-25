# frozen_string_literal: true

class AddContextRuntimeIndexesToInstallments < ActiveRecord::Migration[8.1]
  def change
    add_index :installments, %i[installment_type cash_transaction_id], name: "idx_installments_type_cash_transaction"
    add_index :installments, %i[installment_type card_transaction_id], name: "idx_installments_type_card_transaction"
  end
end
