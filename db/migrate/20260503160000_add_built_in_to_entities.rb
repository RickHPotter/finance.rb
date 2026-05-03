# frozen_string_literal: true

class AddBuiltInToEntities < ActiveRecord::Migration[8.1]
  def change
    add_column :entities, :built_in, :boolean, null: false, default: false
  end
end
