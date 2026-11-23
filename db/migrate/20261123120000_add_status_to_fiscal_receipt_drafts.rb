# frozen_string_literal: true

class AddStatusToFiscalReceiptDrafts < ActiveRecord::Migration[8.1]
  def change
    add_column :fiscal_receipt_drafts, :status, :string, null: false, default: "ready"
    add_column :fiscal_receipt_drafts, :ocr_error, :text
  end
end
