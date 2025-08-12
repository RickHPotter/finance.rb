# frozen_string_literal: true

# Devise User Migration
class CreateDeviseUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :users do |t|
      ## Database authenticatable
      t.string :email,              null: false, default: ""
      t.string :encrypted_password, null: false, default: ""

      ## Recoverable
      t.string   :reset_password_token
      t.datetime :reset_password_sent_at

      ## Rememberable
      t.datetime :remember_created_at

      ## Confirmable
      t.string :confirmation_token
      t.string :unconfirmed_email
      t.datetime :confirmed_at
      t.datetime :confirmation_sent_at

      t.string :first_name, null: false
      t.string :last_name, null: false

      t.string :locale, null: false

      t.timestamps null: false

      t.index [ "email" ],                name: "index_users_on_email",                unique: true
      t.index [ "confirmation_token" ],   name: "index_users_on_confirmation_token",   unique: true
      t.index [ "reset_password_token" ], name: "index_users_on_reset_password_token", unique: true
    end
  end
end
