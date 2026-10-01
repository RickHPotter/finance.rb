# frozen_string_literal: true

class CreateLineItems < ActiveRecord::Migration[8.1]
  def change
    create_table :line_items do |t|
      t.string :transactable_type, null: false
      t.bigint :transactable_id, null: false
      t.string :description, null: false
      t.integer :price, default: 0, null: false
      t.text :comment

      t.timestamps
    end

    add_index :line_items, %i[transactable_type transactable_id]
  end
end
