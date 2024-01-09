# frozen_string_literal: true

# [Money_Card]TransactionEntity Migration
class CreateTransactionEntities < ActiveRecord::Migration[7.1]
  def change
    create_table :transaction_entities do |t|
      t.boolean :is_payer, null: false, default: false
      t.integer :status, null: false, default: 0
      t.decimal :price, null: false, default: 0

      t.references :transactable, null: false, polymorphic: true
      t.references :entity, null: false, foreign_key: true

      t.timestamps
    end
  end
end
