# frozen_string_literal: true

class MigrateFinancialEnumsToStrings < ActiveRecord::Migration[8.1]
  ENTITY_STATUS_CONSTRAINT = "entity_transactions_status_values"
  EXCHANGE_TYPE_CONSTRAINT = "exchanges_exchange_type_values"

  def up
    assert_integer_enum_values!
    reset_legacy_audit_history!

    convert_entity_status_to_string!
    convert_exchange_type_to_string!

    add_check_constraint :entity_transactions,
                         "status IN ('pending', 'finished')",
                         name: ENTITY_STATUS_CONSTRAINT
    add_check_constraint :exchanges,
                         "exchange_type IN ('non_monetary', 'monetary')",
                         name: EXCHANGE_TYPE_CONSTRAINT
  end

  def down
    # The schema conversion is reversible, but the intentionally discarded legacy audit history is not.
    remove_check_constraint :exchanges, name: EXCHANGE_TYPE_CONSTRAINT
    remove_check_constraint :entity_transactions, name: ENTITY_STATUS_CONSTRAINT

    assert_string_enum_values!
    convert_exchange_type_to_integer!
    convert_entity_status_to_integer!
  end

  private

  def assert_integer_enum_values!
    assert_no_rows!("entity_transactions", "status NOT IN (0, 1)")
    assert_no_rows!("exchanges", "exchange_type NOT IN (0, 1)")
  end

  def assert_string_enum_values!
    assert_no_rows!("entity_transactions", "status NOT IN ('pending', 'finished')")
    assert_no_rows!("exchanges", "exchange_type NOT IN ('non_monetary', 'monetary')")
  end

  def assert_no_rows!(table, condition)
    invalid_count = select_value("SELECT COUNT(*) FROM #{quote_table_name(table)} WHERE #{condition}").to_i
    return if invalid_count.zero?

    raise ActiveRecord::MigrationError, "#{table} contains #{invalid_count} unsupported enum values"
  end

  def reset_legacy_audit_history!
    message_count = select_value("SELECT COUNT(*) FROM messages WHERE audit_operation_id IS NOT NULL").to_i
    version_count = select_value("SELECT COUNT(*) FROM audit_versions").to_i
    operation_count = select_value("SELECT COUNT(*) FROM audit_operations").to_i

    say "Resetting #{operation_count} audit operations and #{version_count} audit versions; unlinking #{message_count} messages"

    execute "UPDATE messages SET audit_operation_id = NULL WHERE audit_operation_id IS NOT NULL"
    execute "ALTER TABLE audit_versions DISABLE TRIGGER audit_versions_append_only"
    execute "ALTER TABLE audit_operations DISABLE TRIGGER audit_operations_append_only"
    execute "DELETE FROM audit_versions"
    execute "DELETE FROM audit_operations"
    execute "ALTER TABLE audit_versions ENABLE TRIGGER audit_versions_append_only"
    execute "ALTER TABLE audit_operations ENABLE TRIGGER audit_operations_append_only"
  end

  def convert_entity_status_to_string!
    execute <<~SQL.squish
      ALTER TABLE entity_transactions
      ALTER COLUMN status DROP DEFAULT,
      ALTER COLUMN status TYPE character varying
        USING (CASE status WHEN 0 THEN 'pending' WHEN 1 THEN 'finished' END),
      ALTER COLUMN status SET DEFAULT 'pending'
    SQL
  end

  def convert_exchange_type_to_string!
    execute <<~SQL.squish
      ALTER TABLE exchanges
      ALTER COLUMN exchange_type DROP DEFAULT,
      ALTER COLUMN exchange_type TYPE character varying
        USING (CASE exchange_type WHEN 0 THEN 'non_monetary' WHEN 1 THEN 'monetary' END),
      ALTER COLUMN exchange_type SET DEFAULT 'non_monetary'
    SQL
  end

  def convert_entity_status_to_integer!
    execute <<~SQL.squish
      ALTER TABLE entity_transactions
      ALTER COLUMN status DROP DEFAULT,
      ALTER COLUMN status TYPE integer
        USING (CASE status WHEN 'pending' THEN 0 WHEN 'finished' THEN 1 END),
      ALTER COLUMN status SET DEFAULT 0
    SQL
  end

  def convert_exchange_type_to_integer!
    execute <<~SQL.squish
      ALTER TABLE exchanges
      ALTER COLUMN exchange_type DROP DEFAULT,
      ALTER COLUMN exchange_type TYPE integer
        USING (CASE exchange_type WHEN 'non_monetary' THEN 0 WHEN 'monetary' THEN 1 END),
      ALTER COLUMN exchange_type SET DEFAULT 0
    SQL
  end
end
