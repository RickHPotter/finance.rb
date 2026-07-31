# frozen_string_literal: true

class CreateUserPreferences < ActiveRecord::Migration[8.1]
  def change
    create_table :user_preferences do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.string :theme, null: false, default: "system"
      t.string :landing_page, null: false, default: "dashboard"
      t.integer :active_context_id
      t.string :page_density, null: false, default: "comfortable"
      t.string :date_time_presentation, null: false, default: "relative"
      t.integer :default_account_id
      t.integer :default_card_id

      t.timestamps
    end

    up_only do
      User.find_each do |user|
        UserPreference.create!(
          user_id: user.id,
          theme: "system",
          landing_page: "dashboard",
          active_context_id: user.contexts.first&.id,
          page_density: "comfortable",
          date_time_presentation: "relative"
        )
      end
    end
  end
end
