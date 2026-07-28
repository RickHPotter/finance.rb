# frozen_string_literal: true

class AddAuditOperationToMessages < ActiveRecord::Migration[8.1]
  def change
    add_reference :messages, :audit_operation, type: :uuid, foreign_key: { on_delete: :restrict }
  end
end
