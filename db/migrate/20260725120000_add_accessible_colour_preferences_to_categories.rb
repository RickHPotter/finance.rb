# frozen_string_literal: true

class AddAccessibleColourPreferencesToCategories < ActiveRecord::Migration[8.1]
  LEGACY_PALETTE = {
    "white" => "#f1f5f9",
    "gray" => "#9ca3af",
    "slate" => "#64748b",
    "greek" => "#5b6794",
    "zinc" => "#71717a",
    "stone" => "#78716c",
    "urgency" => "#595657",
    "silver" => "#4b5563",
    "fun" => "#f8f67d",
    "yellow" => "#facc15",
    "gold" => "#eab308",
    "dirt" => "#ca8a04",
    "sand" => "#dfd6ac",
    "cyan" => "#06b6d4",
    "sky" => "#0ea5e9",
    "blue" => "#3b82f6",
    "indigo" => "#6366f1",
    "navy" => "#001861",
    "oldmoney" => "#b9c58f",
    "lettuce" => "#93c560",
    "money" => "#34a853",
    "lime" => "#84cc16",
    "green" => "#22c55e",
    "emerald" => "#10b981",
    "teal" => "#14b8a6",
    "book" => "#2f7361",
    "forest" => "#1c6546",
    "rose" => "#f43f5e",
    "red" => "#ef4444",
    "gift" => "#ce2d46",
    "honda" => "#cc0000",
    "meat" => "#f9906f",
    "bronze" => "#c9a95f",
    "amber" => "#f59e0b",
    "orange" => "#f97316",
    "pink" => "#ec4899",
    "fuchsia" => "#d946ef",
    "purple" => "#a855f7",
    "violet" => "#8b5cf6",
    "plum" => "#6a2d5c"
  }.freeze

  class MigrationCategory < ActiveRecord::Base
    self.table_name = "categories"
  end

  def up
    add_column :categories, :text_colour_mode, :string, null: false, default: "automatic"
    add_column :categories, :text_colour, :string
    change_column_default :categories, :colour, from: "white", to: LEGACY_PALETTE.fetch("white")

    normalize_existing_colours!
    add_contract_constraints
  end

  def down
    remove_contract_constraints
    change_column_default :categories, :colour, from: LEGACY_PALETTE.fetch("white"), to: "white"
    remove_column :categories, :text_colour
    remove_column :categories, :text_colour_mode
  end

  private

  def normalize_existing_colours!
    MigrationCategory.reset_column_information

    MigrationCategory.select(:id, :colour).find_each do |category|
      category.update_columns(colour: normalize_colour(category.colour, category_id: category.id))
    end
  end

  def normalize_colour(value, category_id:)
    raw_value = value.to_s.strip.downcase
    return LEGACY_PALETTE.fetch(raw_value) if LEGACY_PALETTE.key?(raw_value)

    digits = raw_value.delete_prefix("#")
    digits = digits.chars.map { |character| character * 2 }.join if digits.match?(/\A[0-9a-f]{3}\z/)
    return "##{digits}" if digits.match?(/\A[0-9a-f]{6}\z/)

    raise ActiveRecord::MigrationError, "Cannot normalize category ##{category_id} colour #{value.inspect}"
  end

  def add_contract_constraints
    add_check_constraint :categories, "colour ~ '^#[0-9a-f]{6}$'", name: "categories_colour_hex_format"
    add_check_constraint :categories,
                         "text_colour_mode IN ('automatic', 'manual')",
                         name: "categories_text_colour_mode_values"
    add_check_constraint :categories,
                         "text_colour IS NULL OR text_colour ~ '^#[0-9a-f]{6}$'",
                         name: "categories_text_colour_hex_format"
    add_check_constraint :categories,
                         "(text_colour_mode = 'automatic' AND text_colour IS NULL) OR " \
                         "(text_colour_mode = 'manual' AND text_colour IS NOT NULL)",
                         name: "categories_text_colour_mode_payload"
  end

  def remove_contract_constraints
    remove_check_constraint :categories, name: "categories_colour_hex_format"
    remove_check_constraint :categories, name: "categories_text_colour_mode_values"
    remove_check_constraint :categories, name: "categories_text_colour_hex_format"
    remove_check_constraint :categories, name: "categories_text_colour_mode_payload"
  end
end
