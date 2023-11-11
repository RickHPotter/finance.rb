# frozen_string_literal: true

# Categories Migration
class CreateCategories < ActiveRecord::Migration[7.0]
  def change
    create_table :categories do |t|
      t.string :description, null: false, unique: true

      t.timestamps
    end
  end
end
