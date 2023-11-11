# frozen_string_literal: true

# Entity Migration
class CreateEntities < ActiveRecord::Migration[7.0]
  def change
    create_table :entities do |t|
      t.string :entity_name, null: false, unique: true

      t.timestamps
    end
  end
end
