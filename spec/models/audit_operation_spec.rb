# frozen_string_literal: true

require "rails_helper"

RSpec.describe AuditOperation, type: :model do
  subject(:operation) { described_class.create!(source: :web, result: :committed, metadata: { "action" => "create" }) }

  describe "[ persistence contract ]" do
    it "allocates an application UUID and stores structured metadata" do
      expect(operation.id).to match(/\A[0-9a-f-]{36}\z/)
      expect(operation.reload.metadata).to eq("action" => "create")
    end

    it "validates the bounded source and result vocabularies" do
      invalid_operation = described_class.new(source: "other", result: "pending")

      expect(invalid_operation).not_to be_valid
      expect(invalid_operation.errors).to include(:source, :result)
    end

    it "rejects oversized metadata" do
      operation = described_class.new(source: :web, result: :committed, metadata: { "value" => "a" * 17.kilobytes })

      expect(operation).not_to be_valid
      expect(operation.errors).to include(:metadata)
    end
  end

  describe "[ append-only contract ]" do
    it "rejects updates and destruction through Active Record" do
      expect { operation.update!(result: :failed) }.to raise_error(ActiveRecord::ReadOnlyRecord)
      expect { operation.destroy! }.to raise_error(ActiveRecord::ReadOnlyRecord)
    end

    it "rejects direct SQL updates" do
      operation

      expect { described_class.where(id: operation.id).update_all(result: "failed") }
        .to raise_error(ActiveRecord::StatementInvalid, /audit_operations is append-only/)
    end

    it "rejects direct SQL deletes" do
      operation

      expect { described_class.where(id: operation.id).delete_all }
        .to raise_error(ActiveRecord::StatementInvalid, /audit_operations is append-only/)
    end
  end
end

# == Schema Information
#
# Table name: audit_operations
# Database name: primary
#
#  id                       :uuid             not null, primary key
#  metadata                 :jsonb            not null
#  result                   :string           not null
#  source                   :string           not null, indexed => [created_at]
#  created_at               :datetime         not null, indexed => [actor_id], indexed => [context_id], indexed => [source]
#  actor_id                 :bigint           indexed => [created_at]
#  context_id               :bigint           indexed => [created_at]
#  parent_operation_id      :uuid             indexed
#  request_id               :string           indexed
#  rollback_of_operation_id :uuid             indexed
#  selected_version_id      :bigint
#
# Indexes
#
#  index_audit_operations_on_actor_id_and_created_at    (actor_id,created_at)
#  index_audit_operations_on_context_id_and_created_at  (context_id,created_at)
#  index_audit_operations_on_parent_operation_id        (parent_operation_id)
#  index_audit_operations_on_request_id                 (request_id) WHERE (request_id IS NOT NULL)
# rubocop:disable Layout/LineLength
#  index_audit_operations_on_rollback_idempotency       (rollback_of_operation_id, actor_id, ((metadata ->> 'preview_digest'::text))) UNIQUE WHERE (((source)::text = 'rollback'::text) AND ((result)::text = 'committed'::text) AND (rollback_of_operation_id IS NOT NULL) AND (actor_id IS NOT NULL) AND (metadata ? 'preview_digest'::text))
# rubocop:enable Layout/LineLength
#  index_audit_operations_on_rollback_of_operation_id   (rollback_of_operation_id)
#  index_audit_operations_on_source_and_created_at      (source,created_at)
#
