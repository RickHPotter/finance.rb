# frozen_string_literal: true

class RemoveMigrationLater < ActiveRecord::Migration[8.0]
  def change
    return unless table_exists?(:users)
    return unless table_exists?(:categories)

    subscription_category = { built_in: true, category_name: "SUBSCRIPTION" }
    User.find_each do |user|
      next if user.categories.exists?(subscription_category)

      user.categories.create!(subscription_category)
    rescue ActiveRecord::RecordNotUnique
      user.categories.find_by(subscription_category.slice(:category_name)).update!(subscription_category)
    end
  end
end
