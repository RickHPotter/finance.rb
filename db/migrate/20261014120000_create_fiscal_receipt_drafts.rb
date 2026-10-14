# frozen_string_literal: true

class CreateFiscalReceiptDrafts < ActiveRecord::Migration[8.1]
  def change
    create_table :fiscal_receipt_drafts do |t|
      t.references :user, null: false, foreign_key: true
      t.jsonb :payload, null: false, default: {}

      t.timestamps
    end

    add_index :fiscal_receipt_drafts, %i[user_id created_at]
  end
end
