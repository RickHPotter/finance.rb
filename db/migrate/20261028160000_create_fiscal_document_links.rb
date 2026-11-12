# frozen_string_literal: true

class CreateFiscalDocumentLinks < ActiveRecord::Migration[8.1]
  def change
    create_table :fiscal_document_links do |t|
      t.references :user, null: false, foreign_key: true
      t.references :context, null: false, foreign_key: true
      t.string :access_key, null: false, limit: 44
      t.references :transactable, polymorphic: true, null: false, index: { unique: true }
      t.timestamps
    end

    add_index :fiscal_document_links, %i[user_id context_id access_key], name: "index_fiscal_document_links_on_scope_and_key"
    add_check_constraint :fiscal_document_links, "transactable_type IN ('CashTransaction', 'CardTransaction')",
                         name: "fiscal_document_links_transaction_type"
    add_check_constraint :fiscal_document_links, "access_key ~ '^[0-9]{44}$'", name: "fiscal_document_links_access_key_format"
  end
end
