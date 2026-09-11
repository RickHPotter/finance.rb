# frozen_string_literal: true

class AddPublicIdToEntities < ActiveRecord::Migration[8.1]
  def change
    add_column :entities, :public_id, :uuid, null: false, default: -> { "gen_random_uuid()" }
    add_index :entities, :public_id, unique: true
  end
end
