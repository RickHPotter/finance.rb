# frozen_string_literal: true

# Entity Migration
class CreateEntities < ActiveRecord::Migration[8.0]
  def change
    create_table :entities do |t|
      t.string :entity_name, null: false
      t.boolean :active, null: false, default: true
      t.integer :card_transactions_count, null: false, default: 0
      t.integer :card_transactions_total, null: false, default: 0
      t.integer :cash_transactions_count, null: false, default: 0
      t.integer :cash_transactions_total, null: false, default: 0

      t.references :user, null: false, foreign_key: true

      t.timestamps
    end

    add_index :entities, :entity_name, unique: true

    add_index :entities,
              %i[user_id entity_name],
              unique: true,
              name: "index_entity_name_on_composite_key"
  end
end
