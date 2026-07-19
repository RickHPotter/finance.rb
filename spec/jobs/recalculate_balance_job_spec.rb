# frozen_string_literal: true

require "rails_helper"

RSpec.describe RecalculateBalanceJob, type: :job do
  describe "#perform" do
    it "recalculates every user context when no explicit context is given" do
      user = create(:user, :random)
      derived_context = create(:context, user:, name: "Derived", source_context: user.main_context)
      main_service = instance_double(Logic::RecalculateBalancesService, call: true)
      derived_service = instance_double(Logic::RecalculateBalancesService, call: true)

      expect(Logic::RecalculateBalancesService).to receive(:new).with(user:, context: user.main_context).ordered.and_return(main_service)
      expect(main_service).to receive(:call).ordered
      expect(Logic::RecalculateBalancesService).to receive(:new).with(user:, context: derived_context).ordered.and_return(derived_service)
      expect(derived_service).to receive(:call).ordered

      described_class.perform_now(user:)
    end

    it "recalculates only the provided context when explicit" do
      user = create(:user, :random)
      derived_context = create(:context, user:, name: "Derived", source_context: user.main_context)
      service = instance_double(Logic::RecalculateBalancesService, call: true)

      expect(Logic::RecalculateBalancesService).to receive(:new).with(user:, context: derived_context).and_return(service)
      expect(service).to receive(:call)

      described_class.perform_now(user:, context: derived_context)
    end

    it "creates a child operation and restores the parent context" do
      user = create(:user, :random)
      service = instance_double(Logic::RecalculateBalancesService)
      parent_operation = nil
      child_operation = nil

      allow(Logic::RecalculateBalancesService).to receive(:new).with(user:, context: user.main_context).and_return(service)
      allow(service).to receive(:call) { child_operation = Audit::Operation.ensure_persisted! }

      Audit::Operation.run(actor: user, context: user.main_context, source: :web) do
        parent_operation = Audit::Operation.ensure_persisted!
        described_class.perform_now(user:, context: user.main_context)

        expect(Audit::Current.operation_id).to eq(parent_operation.id)
      end

      expect(child_operation.id).not_to eq(parent_operation.id)
      expect(child_operation).to have_attributes(
        actor_id: user.id,
        context_id: user.main_context.id,
        source: "background_job",
        parent_operation_id: parent_operation.id
      )
      expect(Audit::Current).not_to be_active
    end

    it "serializes the initiating operation context when enqueued" do
      user = create(:user, :random)
      job = nil
      parent_operation_id = nil

      Audit::Operation.run(actor: user, context: user.main_context, source: :web) do
        parent_operation_id = Audit::Current.operation_id
        job = described_class.perform_later(user:, context: user.main_context)
      end

      restored_job = described_class.deserialize(job.serialize)

      expect(restored_job).to have_attributes(
        audit_parent_operation_id: parent_operation_id,
        audit_actor_id: user.id,
        audit_context_id: user.main_context.id
      )
      expect(Audit::Current).not_to be_active
    end
  end
end
