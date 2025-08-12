# frozen_string_literal: true

class CreateBudgetEntities < ActiveRecord::Migration[8.0]
  def change
    create_table :budget_entities do |t|
      t.references :budget, null: false, foreign_key: true
      t.references :entity, null: false, foreign_key: true

      t.timestamps

      t.index %w[budget_id entity_id], name: "index_budget_entities_on_composite_key", unique: true
    end
  end
end
