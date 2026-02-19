# frozen_string_literal: true

class AddFirstInstallmentOnlyToBudgets < ActiveRecord::Migration[8.1]
  def change
    add_column :budgets, :first_installment_only, :boolean, default: false, null: false
  end
end
