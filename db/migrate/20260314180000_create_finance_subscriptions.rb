# frozen_string_literal: true

class CreateFinanceSubscriptions < ActiveRecord::Migration[8.0]
  def change
    create_table :finance_subscriptions do |t|
      t.references :user, null: false, foreign_key: true
      t.string :description, null: false
      t.integer :price, null: false, default: 0
      t.text :comment
      t.string :status, null: false, default: "active"

      t.timestamps
    end

    add_index :finance_subscriptions, :status
  end
end
