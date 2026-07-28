# frozen_string_literal: true

class AddRollbackIdempotencyIndex < ActiveRecord::Migration[8.1]
  INDEX_NAME = "index_audit_operations_on_rollback_idempotency"

  def up
    execute <<~SQL.squish
      CREATE UNIQUE INDEX #{INDEX_NAME}
      ON audit_operations (rollback_of_operation_id, actor_id, (metadata ->> 'preview_digest'))
      WHERE source = 'rollback'
        AND result = 'committed'
        AND rollback_of_operation_id IS NOT NULL
        AND actor_id IS NOT NULL
        AND metadata ? 'preview_digest'
    SQL
  end

  def down
    remove_index :audit_operations, name: INDEX_NAME
  end
end
