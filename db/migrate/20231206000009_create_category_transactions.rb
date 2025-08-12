# frozen_string_literal: true

# Category[Cash/Card]Transaction Migration
class CreateCategoryTransactions < ActiveRecord::Migration[8.0]
  def change
    create_table :category_transactions do |t|
      t.references :category, null: false, foreign_key: true
      t.references :transactable, null: false, polymorphic: true

      t.timestamps

      t.index %w[category_id transactable_type transactable_id], name: "index_category_transactions_on_composite_key", unique: true
    end
  end
end
