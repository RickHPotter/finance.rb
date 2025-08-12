# frozen_string_literal: true

class CreateBudgetCategories < ActiveRecord::Migration[8.0]
  def change
    create_table :budget_categories do |t|
      t.references :budget, null: false, foreign_key: true
      t.references :category, null: false, foreign_key: true

      t.timestamps

      t.index %w[budget_id category_id], name: "index_budget_categories_on_composite_key", unique: true
    end
  end
end
