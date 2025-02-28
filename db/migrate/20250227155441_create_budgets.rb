# frozen_string_literal: true

class CreateBudgets < ActiveRecord::Migration[8.0]
  def change
    create_table :budgets do |t|
      t.integer :month, null: false
      t.integer :year, null: false
      t.integer :budget_value, null: false
      t.integer :remaining_value, null: false
      t.boolean :inclusive, null: false, default: true
      t.boolean :active, null: false, default: true

      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
  end
end
