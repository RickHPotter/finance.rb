# frozen_string_literal: true

class CreateUserProfiles < ActiveRecord::Migration[8.1]
  def change
    create_table :user_profiles do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.string :display_name
      t.string :first_name
      t.string :last_name
      t.string :locale, null: false, default: "en"
      t.string :timezone, null: false, default: "UTC"
      t.string :sex, default: "not_specified", null: false

      t.timestamps
    end

    up_only do
      User.find_each do |user|
        display_name = [ user.first_name, user.last_name ].compact.join(" ").presence || user.email.split("@").first
        UserProfile.create!(
          user_id: user.id,
          first_name: user.first_name,
          last_name: user.last_name,
          display_name:,
          locale: user.locale || "en",
          timezone: "UTC"
        )
      end
    end
  end
end
