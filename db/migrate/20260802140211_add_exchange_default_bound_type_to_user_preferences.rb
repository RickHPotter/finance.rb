# frozen_string_literal: true

class AddExchangeDefaultBoundTypeToUserPreferences < ActiveRecord::Migration[8.1]
  def change
    add_column :user_preferences, :exchange_default_bound_type, :string, default: "standalone", null: false
    add_column :user_preferences, :row_color_mode, :string, default: "badges_only", null: false
  end
end
