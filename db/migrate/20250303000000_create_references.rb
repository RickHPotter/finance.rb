# frozen_string_literal: true

class CreateReferences < ActiveRecord::Migration[8.0]
  def change
    create_table :references do |t|
      t.references :user_card, null: false, foreign_key: true
      t.integer :month, null: false
      t.integer :year, null: false
      t.date :reference_date, null: false

      t.timestamps

      t.index %w[user_card_id month year], name: "idx_references_user_card_month_year", unique: true
    end
  end
end
