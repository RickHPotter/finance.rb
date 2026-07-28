# frozen_string_literal: true

class AddHealthCheckRepairIdempotencyIndex < ActiveRecord::Migration[8.1]
  INDEX_NAME = "index_audit_operations_on_health_repair_idempotency"

  def up
    execute <<~SQL.squish
      CREATE UNIQUE INDEX #{INDEX_NAME}
      ON audit_operations (actor_id, context_id, (metadata ->> 'idempotency_key'))
      WHERE source = 'admin_repair'
        AND result = 'committed'
        AND actor_id IS NOT NULL
        AND context_id IS NOT NULL
        AND metadata ? 'idempotency_key'
    SQL
  end

  def down
    remove_index :audit_operations, name: INDEX_NAME
  end
end
