# frozen_string_literal: true

class FixBudgetsDefaultRemoveLater < ActiveRecord::Migration[8.0]
  def change
    return unless table_exists?(:budgets)

    change_column_default :budgets, :inclusive, false
    Budget.update_all(inclusive: false)
  end
end
