# frozen_string_literal: true

# Migration to fix some lapses
class FixEarlierMigrations < ActiveRecord::Migration[7.0]
  def fix_user_id
    %i[card_transactions user_cards categories entities].each do |table|
      change_column table, :user_id, :integer, null: false if column_exists?(table, :user_id)
    end
  end

  def fix_card_id
    %i[card_transactions user_cards].each do |table|
      change_column table, :card_id, :integer, null: false if column_exists?(table, :card_id)
    end
  end

  def fix_installments_columns
    if column_exists?(:installments, :price)
      change_column :installments, :price, :decimal, precision: 10, scale: 2, null: false, default: 0.00
    end
    change_column :installments, :number, :integer, null: false, default: 1 if column_exists?(:installments, :number)
  end

  def fix_installments_id
    return unless column_exists?(:card_transactions, :installment_id)

    change_column :card_transactions, :installment_id, :integer, null: true
  end

  def fix_user_card_due_date
    change_column :user_cards, :due_date, :integer, null: false if column_exists?(:user_cards, :due_date)
  end

  def implement_confirmable_to_users
    add_column :users, :confirmed_at, :datetime unless column_exists?(:users, :confirmed_at)
    add_column :users, :confirmation_sent_at, :datetime unless column_exists?(:users, :confirmation_sent_at)
    add_column :users, :unconfirmed_email, :string unless column_exists?(:users, :unconfirmed_email)
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
