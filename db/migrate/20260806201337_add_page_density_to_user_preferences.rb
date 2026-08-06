# frozen_string_literal: true

class AddPageDensityToUserPreferences < ActiveRecord::Migration[8.1]
  def change
    add_column :user_preferences, :page_density, :string, default: "default", null: false
  end
end
