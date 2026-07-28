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

    it "isolates audit state between sequential jobs" do
      users = create_list(:user, 2, :random)
      observed_boundaries = []
      allow(Logic::RecalculateBalancesService).to receive(:new) do |**|
        service = instance_double(Logic::RecalculateBalancesService)
        allow(service).to receive(:call) do
          observed_boundaries << Audit::Current.attributes.slice(:operation_id, :actor_id, :context_id, :root_source)
        end
        service
      end

      users.each do |user|
        job = described_class.new(user:, context: user.main_context)
        job.audit_actor_id = user.id
        job.audit_context_id = user.main_context.id
        job.perform_now
        expect(Audit::Current).not_to be_active
      end

      expect(observed_boundaries.map { |boundary| boundary[:operation_id] }.uniq.size).to eq(2)
      expect(observed_boundaries.map { |boundary| boundary[:actor_id] }).to eq(users.map(&:id))
      expect(observed_boundaries.map { |boundary| boundary[:context_id] }).to eq(users.map { |user| user.main_context.id })
      expect(observed_boundaries.pluck(:root_source)).to eq(%w[background_job background_job])
      expect(PaperTrail.request.whodunnit).to be_nil
    end
  end
end
