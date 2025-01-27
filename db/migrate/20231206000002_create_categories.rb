# frozen_string_literal: true

# Category Migration
class CreateCategories < ActiveRecord::Migration[8.0]
  def change
    create_table :categories do |t|
      t.string :category_name, null: false, unique: true
      t.boolean :built_in, null: false, default: false

      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
  end
end
