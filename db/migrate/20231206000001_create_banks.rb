# frozen_string_literal: true

# Bank Migration
class CreateBanks < ActiveRecord::Migration[8.0]
  def change
    create_table :banks do |t|
      t.string :bank_name, null: false
      t.string :bank_code, null: false

      t.timestamps
    end
  end
end
