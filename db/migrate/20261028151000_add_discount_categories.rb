# frozen_string_literal: true

class AddDiscountCategories < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      UPDATE categories
         SET built_in = TRUE, active = TRUE, updated_at = CURRENT_TIMESTAMP
       WHERE category_name = 'DISCOUNT' AND parent_category_id IS NULL
    SQL

    execute <<~SQL
      INSERT INTO categories (user_id, category_name, built_in, active, created_at, updated_at)
      SELECT users.id, 'DISCOUNT', TRUE, TRUE, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
        FROM users
       WHERE NOT EXISTS (
         SELECT 1 FROM categories
          WHERE categories.user_id = users.id AND categories.category_name = 'DISCOUNT'
            AND categories.parent_category_id IS NULL
       )
    SQL
  end

  def down
    # Existing categories and their history must not be removed or reclassified.
  end
end
