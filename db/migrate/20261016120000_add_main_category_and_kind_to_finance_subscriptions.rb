# frozen_string_literal: true

class AddMainCategoryAndKindToFinanceSubscriptions < ActiveRecord::Migration[8.1]
  def up
    add_column :finance_subscriptions, :subscription_kind, :string, default: "expense", null: false
    add_reference :finance_subscriptions, :main_category, foreign_key: { to_table: :categories }, index: true
    add_check_constraint :finance_subscriptions, "subscription_kind IN ('expense', 'income')", name: "finance_subscriptions_kind_values"

    execute <<~SQL
      UPDATE finance_subscriptions AS subscription
      SET main_category_id = category.id
      FROM categories AS category
      WHERE category.user_id = subscription.user_id
        AND category.category_name = 'SUBSCRIPTION'
        AND category.parent_category_id IS NULL;
    SQL

    missing_count = select_value("SELECT COUNT(*) FROM finance_subscriptions WHERE main_category_id IS NULL").to_i
    raise "Could not assign the main SUBSCRIPTION category to #{missing_count} existing subscriptions" if missing_count.positive?

    change_column_null :finance_subscriptions, :main_category_id, false
  end

  def down
    remove_check_constraint :finance_subscriptions, name: "finance_subscriptions_kind_values"
    remove_reference :finance_subscriptions, :main_category, foreign_key: { to_table: :categories }
    remove_column :finance_subscriptions, :subscription_kind
  end
end
