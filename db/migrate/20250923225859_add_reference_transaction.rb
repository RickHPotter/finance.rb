# frozen_string_literal: true

class AddReferenceTransaction < ActiveRecord::Migration[8.0]
  def change
    change_table :card_transactions do |t|
      t.references :reference_transactable, null: true, polymorphic: true

      t.index %w[reference_transactable_type reference_transactable_id], name: "index_reference_transactable_on_card_composite_key", unique: true
    end

    change_table :cash_transactions do |t|
      t.references :reference_transactable, null: true, polymorphic: true

      t.index %w[reference_transactable_type reference_transactable_id], name: "index_reference_transactable_on_cash_composite_key", unique: true
    end

    Message.where.not(headers: nil).find_each do |message|
      headers = JSON.parse(message.headers)
      new_headers = {}
      new_headers.merge!(id: headers["id"], type: headers["cash_installments_attributes"].count > 1 ? "CardTransaction" : "CashTransaction")

      new_headers.merge!(headers.slice("description", "price", "date", "month", "year", "category_ids", "entity_ids", "cash_installments_attributes"))

      message.update(headers: new_headers.to_json)
    end
  end
end
