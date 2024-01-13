# frozen_string_literal: true

# installment Migration
class CreateInstallments < ActiveRecord::Migration[7.0]
  def change
    create_table :installments do |t|
      t.decimal :price, default: 0.00, precision: 10, scale: 2, null: false
      t.integer :number, default: 1, null: false

      t.references :installable, polymorphic: true, null: false

      t.timestamps
    end
  end
end
