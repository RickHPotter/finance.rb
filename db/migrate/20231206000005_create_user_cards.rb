# frozen_string_literal: true

# UserCard Migration
class CreateUserCards < ActiveRecord::Migration[7.0]
  def change
    create_table :user_cards do |t|
      t.string :user_card_name, null: false, unique: true
      t.integer :days_until_due_date, null: false
      t.date :current_closing_date, null: false
      t.date :current_due_date, null: false
      t.decimal :min_spend, null: false
      t.decimal :credit_limit, null: false
      t.boolean :active, null: false

      t.references :user, null: false
      t.references :card, null: false

      t.timestamps
    end
  end
end
