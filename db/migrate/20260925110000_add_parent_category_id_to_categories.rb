# frozen_string_literal: true

class AddParentCategoryIdToCategories < ActiveRecord::Migration[8.1]
  def up
    add_reference :categories, :parent_category, foreign_key: { to_table: :categories, on_delete: :restrict }, index: true, null: true
    add_check_constraint :categories, "parent_category_id IS NULL OR parent_category_id <> id", name: "categories_no_self_parent"

    remove_index :categories, name: "index_category_name_on_composite_key"
    execute <<~SQL
      CREATE UNIQUE INDEX index_categories_on_user_id_parent_and_name
      ON categories (user_id, parent_category_id, category_name) NULLS NOT DISTINCT;
    SQL
  end

  def down
    execute <<~SQL
      DROP INDEX IF EXISTS index_categories_on_user_id_parent_and_name;
    SQL
    add_index :categories, %i[user_id category_name], unique: true, name: "index_category_name_on_composite_key"

    remove_check_constraint :categories, name: "categories_no_self_parent"
    remove_reference :categories, :parent_category, foreign_key: { to_table: :categories }
  end
end
