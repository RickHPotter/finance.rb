# frozen_string_literal: true

# Entity Migration
class CreateEntities < ActiveRecord::Migration[8.0]
  def change
    create_table :entities do |t|
      t.string :entity_name, null: false, unique: true

      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
  end
end
