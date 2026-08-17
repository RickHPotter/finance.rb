# frozen_string_literal: true

class MigrateUserFieldsToUserProfile < ActiveRecord::Migration[8.1]
  def change
    remove_column :users, :first_name, :string
    remove_column :users, :last_name, :string
    remove_column :users, :locale, :string
  end
end
