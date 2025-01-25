# frozen_string_literal: true

# Category[Cash/Card]Transaction Migration
class CreateCategoryTransactions < ActiveRecord::Migration[7.1]
  def change
    create_table :category_transactions do |t|
      t.references :category, null: false, foreign_key: true
      t.references :transactable, null: false, polymorphic: true

      t.timestamps
    end

    add_index :category_transactions,
              %i[category_id transactable_type transactable_id],
              unique: true,
              name: "index_category_transactions_on_composite_key"
  end
end
