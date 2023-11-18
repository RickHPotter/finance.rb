# frozen_string_literal: true

# installments Migration
class CreateInstallments < ActiveRecord::Migration[7.0]
  def change
    create_table :installments do |t|
      t.references :installable, polymorphic: true, null: false
      t.decimal :price
      t.integer :number

      t.timestamps
    end
  end
end
