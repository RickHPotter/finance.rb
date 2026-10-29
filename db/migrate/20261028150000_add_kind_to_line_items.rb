# frozen_string_literal: true

class AddKindToLineItems < ActiveRecord::Migration[8.1]
  def change
    add_column :line_items, :item_kind, :string, null: false, default: "product"
    add_check_constraint :line_items, "item_kind IN ('product', 'discount')", name: "line_items_item_kind_values"
    add_index :line_items, %i[transactable_type transactable_id], unique: true, where: "item_kind = 'discount'",
                                                               name: "index_line_items_one_discount_per_transaction"
  end
end
