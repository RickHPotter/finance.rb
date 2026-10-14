# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Audit query plans" do
  let(:connection) { ActiveRecord::Base.connection }

  before { connection.execute("SET LOCAL enable_seqscan = off") }

  it "uses record-history and owner-history indexes" do
    record_plan = explain(<<~SQL)
      SELECT id, operation_id, created_at
      FROM audit_versions
      WHERE item_type = 'CashTransaction' AND item_id = 42
      ORDER BY created_at DESC
    SQL
    owner_plan = explain(<<~SQL)
      SELECT id, operation_id, created_at
      FROM audit_versions
      WHERE owner_id = 17
      ORDER BY created_at DESC
    SQL

    expect(record_plan).to include("index_audit_versions_on_item_type_and_item_id_and_created_at")
    expect(owner_plan).to include("index_audit_versions_on_owner_id_and_created_at")
  end

  it "uses operation chronology and operation-version indexes" do
    seed_operation_version_rows

    source_plan = explain(<<~SQL)
      SELECT id, created_at
      FROM audit_operations
      WHERE source = 'web'
      ORDER BY created_at DESC
    SQL
    operation_versions_plan = explain(<<~SQL)
      SELECT id, item_type, item_id
      FROM audit_versions
      WHERE operation_id = '00000000-0000-4000-8000-000000000001'
      ORDER BY id ASC
    SQL

    expect(source_plan).to include("index_audit_operations_on_source_and_created_at")
    expect(operation_versions_plan).to include("index_audit_versions_on_operation_id_and_id")
  end

  it "keeps operation indexes independent from version JSON payload columns" do
    user = create(:user, :random)
    sql = Audit::OperationQuery.new(reader: user).relation.to_sql

    expect(sql).to include("SELECT \"audit_versions\".\"operation_id\"")
    expect(sql).not_to include("object_changes", "audit_versions\".*")
  end

  def explain(sql)
    connection.select_values("EXPLAIN (COSTS OFF) #{sql.squish}").join("\n")
  end

  def seed_operation_version_rows
    target_operation_id = "00000000-0000-4000-8000-000000000001"
    connection.execute(<<~SQL)
      INSERT INTO audit_operations (id, source, result, created_at)
      VALUES ('#{target_operation_id}', 'web', 'committed', CURRENT_TIMESTAMP);

      INSERT INTO audit_operations (source, result, created_at)
      SELECT 'web', 'committed', CURRENT_TIMESTAMP
      FROM generate_series(1, 1000);

      INSERT INTO audit_versions (item_type, item_id, event, operation_id, owner_id, mutation_source, created_at)
      SELECT 'CashTransaction', row_number() OVER (), 'update', id, 17, 'web', CURRENT_TIMESTAMP
      FROM audit_operations;

      ANALYZE audit_versions;
    SQL
  end
end
