# frozen_string_literal: true

# Migration to fix some lapses
class FixEarlierMigrations < ActiveRecord::Migration[7.0]
  def fix_user_id
    change_column :card_transactions, :user_id, :integer, null: false
    change_column :user_cards, :user_id, :integer, null: false
    change_column :categories, :user_id, :integer, null: false
    change_column :entities, :user_id, :integer, null: false
  end

  def fix_card_id
    change_column :card_transactions, :card_id, :integer, null: false
    change_column :user_cards, :card_id, :integer, null: false
  end

  def fix_installments_columns
    change_column :installments, :price, :decimal, precision: 10, scale: 2, null: false, default: 0.00
    change_column :installments, :number, :integer, null: false, default: 1
  end

  def fix_installments_id
    change_column :card_transactions, :installment_id, :integer, null: true
  end

  def fix_user_card_due_date
    change_column :user_cards, :due_date, :integer, null: false
  end

  def implement_confirmable_to_users
    add_column :users, :confirmed_at, :datetime
    add_column :users, :confirmation_sent_at, :datetime
    add_column :users, :unconfirmed_email, :string
  end

  def change
    fix_user_id
    fix_card_id
    fix_installments_columns
    fix_installments_id
    fix_user_card_due_date
    implement_confirmable_to_users
  end
end
