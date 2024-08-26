# frozen_string_literal: true

# Entity/Transaction Migration
class CreateEntityTransactions < ActiveRecord::Migration[7.1]
  def change
    create_table :entity_transactions do |t|
      t.boolean :is_payer, null: false, default: false
      t.integer :status, null: false, default: 0
      t.integer :price, null: false, default: 0
      t.integer :exchanges_count, default: 0, null: false

      t.references :entity, null: false, foreign_key: true
      t.references :transactable, null: false, polymorphic: true

      t.timestamps
    end

    add_index :entity_transactions,
              %i[entity_id transactable_type transactable_id],
              unique: true,
              name: "index_entity_transactions_on_composite_key"
  end
end
