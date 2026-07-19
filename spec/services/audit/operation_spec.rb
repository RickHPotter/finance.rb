# frozen_string_literal: true

require "rails_helper"

RSpec.describe Audit::Operation do
  let(:actor) { create(:user, :random) }
  let(:context) { actor.main_context }

  describe ".run" do
    it "exposes isolated request context without eagerly creating a row" do
      operation_id = nil

      expect do
        described_class.run(actor:, context:, source: :web, request_id: "request-123") do
          operation_id = Audit::Current.operation_id

          expect(Audit::Current.actor_id).to eq(actor.id)
          expect(Audit::Current.context_id).to eq(context.id)
          expect(Audit::Current.request_id).to eq("request-123")
          expect(Audit::Current.root_source).to eq("web")
          expect(Audit::Current.mutation_source).to eq("web")
          expect(PaperTrail.request.whodunnit).to eq(actor.id.to_s)
        end
      end.not_to change(AuditOperation, :count)

      expect(operation_id).to be_present
      expect(Audit::Current).not_to be_active
      expect(PaperTrail.request.whodunnit).to be_nil
    end

    it "persists one operation lazily and reuses it for nested work" do
      records = []

      described_class.run(actor:, context:, source: :web) do
        records << described_class.ensure_persisted!
        described_class.run(source: :import) { records << described_class.ensure_persisted! }
      end

      expect(records.map(&:id).uniq.one?).to be(true)
      expect(records.first).to have_attributes(actor_id: actor.id, context_id: context.id, source: "web", result: "committed")
    end

    it "restores the immediate source after nested synchronization" do
      observed_sources = []

      described_class.run(source: :web) do
        observed_sources << Audit::Current.mutation_source
        described_class.with_mutation_source(:projection_sync) { observed_sources << Audit::Current.mutation_source }
        observed_sources << Audit::Current.mutation_source
      end

      expect(observed_sources).to eq(%w[web projection_sync web])
    end

    it "clears operation and PaperTrail state after an exception" do
      expect do
        described_class.run(actor:, context:, source: :web) { raise "operation failed" }
      end.to raise_error("operation failed")

      expect(Audit::Current).not_to be_active
      expect(PaperTrail.request.whodunnit).to be_nil
    end

    it "removes the operation with a rolled back business transaction" do
      expect do
        AuditOperation.transaction do
          described_class.run(source: :web) { described_class.ensure_persisted! }
          raise ActiveRecord::Rollback
        end
      end.not_to change(AuditOperation, :count)
    end

    it "rejects unsupported sources and unbounded metadata shapes" do
      expect { described_class.run(source: :other) { true } }.to raise_error(described_class::InvalidContextError)
      expect { described_class.run(source: :web, metadata: { params: { unsafe: true } }) { true } }.to raise_error(described_class::InvalidContextError)
    end
  end

  describe ".with_mutation_source" do
    it "uses an unknown root for explicitly wrapped work outside a boundary" do
      operation = nil

      described_class.with_mutation_source(:balance_recalculation) do
        expect(Audit::Current.root_source).to eq("unknown")
        expect(Audit::Current.mutation_source).to eq("balance_recalculation")
        operation = described_class.ensure_persisted!
      end

      expect(operation.source).to eq("unknown")
      expect(Audit::Current).not_to be_active
    end
  end

  describe ".ensure_persisted!" do
    it "creates a standalone unknown operation for an unwrapped mutation" do
      expect(described_class.ensure_persisted!).to be_source_unknown
      expect(Audit::Current).not_to be_active
    end
  end
end
