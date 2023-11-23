# frozen_string_literal: true

# Migration for creating UserCard
class CreateUserCards < ActiveRecord::Migration[7.0]
  def change
    create_table :user_cards do |t|
      t.references :user
      t.references :card
      t.string :card_name, null: false, unique: true
      t.date :due_date, null: false
      t.decimal :min_spend, null: false
      t.decimal :credit_limit, null: false
      t.boolean :active, null: false

      t.timestamps
    end
  end
end
