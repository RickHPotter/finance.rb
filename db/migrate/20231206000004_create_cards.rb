# frozen_string_literal: true

# Card Migration
class CreateCards < ActiveRecord::Migration[8.0]
  def change
    create_table :cards do |t|
      t.string :card_name, null: false

      t.references :bank, null: false, foreign_key: true

      t.timestamps
    end

    add_index :cards, :card_name, unique: true
  end
end
