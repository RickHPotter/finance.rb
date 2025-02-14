# frozen_string_literal: true

# Category Migration
class CreateCategories < ActiveRecord::Migration[8.0]
  def change
    create_table :categories do |t|
      t.string :category_name, null: false
      t.boolean :built_in, null: false, default: false
      t.boolean :active, null: false, default: true
      t.string :colour, null: false, default: :white

      t.references :user, null: false, foreign_key: true

      t.timestamps
    end

    add_index :categories,
              %i[user_id category_name],
              unique: true,
              name: "index_category_name_on_composite_key"
  end
end
