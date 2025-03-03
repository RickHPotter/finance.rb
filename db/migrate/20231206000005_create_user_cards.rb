# frozen_string_literal: true

# UserCard Migration
class CreateUserCards < ActiveRecord::Migration[8.0]
  def change
    create_table :user_cards do |t|
      t.string :user_card_name, null: false
      t.integer :days_until_due_date, null: false
      t.integer :due_date_day, null: false, default: 1
      t.integer :min_spend, null: false
      t.integer :credit_limit, null: false
      t.boolean :active, null: false, default: true
      t.integer :card_transactions_count, null: false, default: 0
      t.integer :card_transactions_total, null: false, default: 0

      t.references :user, null: false
      t.references :card, null: false

      t.timestamps

      t.index [ "user_card_name" ], name: "index_user_cards_on_user_card_name", unique: true
    end
  end
end
