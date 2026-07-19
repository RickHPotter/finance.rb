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
