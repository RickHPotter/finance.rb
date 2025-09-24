# frozen_string_literal: true

class AddAdminToUsers < ActiveRecord::Migration[8.0]
  def change
    change_table :users do |t|
      t.boolean :admin, null: false, default: false
    end

    User.first&.update_columns(admin: true)
    User.second&.update_columns(admin: true)
  end
end
