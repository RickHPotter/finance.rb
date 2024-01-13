# frozen_string_literal: true

# Category[Money_Card]Transaction Migration
class CreateCategoryTransactions < ActiveRecord::Migration[7.1]
  def change
    create_table :category_transactions do |t|
      t.references :category, null: false, foreign_key: true
      t.references :transactable, null: false, polymorphic: true

      t.timestamps
    end
  end
end
