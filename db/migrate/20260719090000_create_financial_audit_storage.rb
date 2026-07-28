# frozen_string_literal: true

class CreateFinancialAuditStorage < ActiveRecord::Migration[8.1]
  ROOT_SOURCES = %w[web api actionable_message admin_repair import background_job rollback console unknown].freeze
  MUTATION_SOURCES = (ROOT_SOURCES + %w[shared_sync projection_sync reference_sync piggy_bank_sync balance_recalculation]).freeze
  OPERATION_RESULTS = %w[committed rejected failed].freeze
  VERSION_EVENTS = %w[create update destroy].freeze

  def up
    create_audit_operations
    create_audit_versions
    add_audit_constraints
    add_append_only_triggers
  end

  def down
    remove_append_only_triggers
    drop_table :audit_versions
    drop_table :audit_operations
  end

  private

  def create_audit_operations
    create_table :audit_operations, id: :uuid do |t|
      t.bigint :actor_id
      t.bigint :context_id
      t.string :request_id
      t.string :source, null: false
      t.string :result, null: false
      t.uuid :parent_operation_id
      t.uuid :rollback_of_operation_id
      t.bigint :selected_version_id
      t.jsonb :metadata, null: false, default: {}
      t.datetime :created_at, null: false

      t.index %i[actor_id created_at]
      t.index %i[context_id created_at]
      t.index %i[source created_at]
      t.index :parent_operation_id
      t.index :rollback_of_operation_id
      t.index :request_id, where: "request_id IS NOT NULL"
    end
  end

  def create_audit_versions
    create_table :audit_versions do |t|
      t.string :item_type, null: false
      t.string :item_subtype
      t.bigint :item_id, null: false
      t.string :event, null: false
      t.string :whodunnit
      t.jsonb :object
      t.jsonb :object_changes
      t.uuid :operation_id, null: false
      t.bigint :owner_id, null: false
      t.bigint :context_id
      t.string :mutation_source, null: false
      t.jsonb :metadata, null: false, default: {}
      t.datetime :created_at, null: false

      t.index %i[operation_id id]
      t.index %i[item_type item_id created_at]
      t.index %i[owner_id created_at]
      t.index %i[context_id created_at]
      t.index %i[mutation_source created_at]
      t.index %i[event created_at]
    end

    add_foreign_key :audit_versions, :audit_operations, column: :operation_id, primary_key: :id, on_delete: :restrict
  end

  def add_audit_constraints
    add_check_constraint :audit_operations, "source IN (#{quoted_values(ROOT_SOURCES)})", name: "audit_operations_source"
    add_check_constraint :audit_operations, "result IN (#{quoted_values(OPERATION_RESULTS)})", name: "audit_operations_result"
    add_check_constraint :audit_operations, "octet_length(metadata::text) <= 16384", name: "audit_operations_metadata_size"

    add_check_constraint :audit_versions, "event IN (#{quoted_values(VERSION_EVENTS)})", name: "audit_versions_event"
    add_check_constraint :audit_versions, "mutation_source IN (#{quoted_values(MUTATION_SOURCES)})", name: "audit_versions_mutation_source"
    add_check_constraint :audit_versions, "octet_length(metadata::text) <= 16384", name: "audit_versions_metadata_size"
    add_check_constraint :audit_versions,
                         "object IS NULL OR octet_length(object::text) <= 262144",
                         name: "audit_versions_object_size"
    add_check_constraint :audit_versions,
                         "object_changes IS NULL OR octet_length(object_changes::text) <= 262144",
                         name: "audit_versions_object_changes_size"
  end

  def add_append_only_triggers
    execute <<~SQL
      CREATE FUNCTION prevent_financial_audit_mutation()
      RETURNS trigger
      LANGUAGE plpgsql
      AS $$
      BEGIN
        RAISE EXCEPTION '% is append-only', TG_TABLE_NAME
          USING ERRCODE = 'integrity_constraint_violation';
      END;
      $$;
    SQL

    %w[audit_operations audit_versions].each do |table|
      execute <<~SQL
        CREATE TRIGGER #{table}_append_only
        BEFORE UPDATE OR DELETE ON #{table}
        FOR EACH ROW EXECUTE FUNCTION prevent_financial_audit_mutation();
      SQL
    end
  end

  def remove_append_only_triggers
    %w[audit_operations audit_versions].each do |table|
      execute "DROP TRIGGER IF EXISTS #{table}_append_only ON #{table};"
    end
    execute "DROP FUNCTION IF EXISTS prevent_financial_audit_mutation();"
  end

  def quoted_values(values)
    values.map { |value| connection.quote(value) }.join(", ")
  end
end
