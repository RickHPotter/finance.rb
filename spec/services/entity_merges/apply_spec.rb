# frozen_string_literal: true

require "rails_helper"

RSpec.describe "EntityMerges::Apply" do
  let(:user) { create(:user) }
  let(:source) { create(:entity, :random, user:) }
  let(:destination) { create(:entity, :random, user:) }
  let(:context) { user.main_context }
  let(:bank) { create(:bank) }
  let(:user_bank_account) { create(:user_bank_account, user:, bank:) }

  let(:neutral_txn) do
    create(:cash_transaction, user:, context:, user_bank_account:, price: 0).tap do |t|
      t.entity_transactions.create!(entity: source, price: 0, is_payer: false)
    end
  end

  let(:monetary_txn) do
    create(:cash_transaction, user:, context:, user_bank_account:, price: 0).tap do |t|
      t.entity_transactions.create!(entity: source, price: 100, is_payer: false)
    end
  end

  def apply(mode: :strict)
    plan = EntityMerges::Planner.new(actor: user, context:, source_id: source.id, destination_id: destination.id, mode:).call
    apply_plan(plan, mode:)
  end

  def apply_plan(plan, mode: plan.mode)
    token = EntityMerges::PreviewToken.generate(plan)
    EntityMerges::Apply.new(actor: user, context:, source_id: source.id, token:, confirmed: true, mode:).call
  end

  describe "strict mode" do
    it "transfers neutral rows and destroys source" do
      neutral_txn
      result = apply(mode: :strict)

      expect(result).to be_applied
      expect(EntityTransaction.where(entity: destination).count).to eq(1)
      expect(Entity.exists?(source.id)).to be(false)
      expect(destination.reload.cash_transactions_count).to eq(1)

      op = result.operation
      expect(op.metadata["entity_merge"]).to be(true)
      expect(op.metadata["source_destroyed"]).to be(true)
    end

    it "rejects if conflicts exist" do
      monetary_txn
      result = apply(mode: :strict)
      expect(result).to be_rejected
      expect(result.reason_code).to eq("merge_ineligible")
      expect(Entity.exists?(source.id)).to be(true)
    end

    it "refreshes a Budget description after transferring its allocation" do
      budget = create(
        :budget,
        user:,
        context:,
        month: 8,
        year: 2026,
        budget_categories: [],
        budget_entities: [ build(:budget_entity, entity: source) ]
      )

      result = apply

      expect(result).to be_applied
      expect(budget.reload.entities).to contain_exactly(destination)
      expect(budget.description).to include(destination.name)
      expect(budget.description).not_to include(source.name)
    end

    it "rejects an allocation added after preview without mutating the source" do
      preview = EntityMerges::Planner.new(actor: user, context:, source_id: source.id, destination_id: destination.id, mode: :strict).call
      neutral_txn
      result = nil

      expect { result = apply_plan(preview) }.not_to(change { Entity.exists?(source.id) })
      expect(result).to be_rejected
      expect(result.reason_code).to eq("stale_preview")
      expect(neutral_txn.reload.entities).to include(source)
    end

    it "rejects a mode that was not bound to the preview" do
      plan = EntityMerges::Planner.new(actor: user, context:, source_id: source.id, destination_id: destination.id, mode: :strict).call
      token = EntityMerges::PreviewToken.generate(plan)
      result = EntityMerges::Apply.new(actor: user, context:, source_id: source.id, token:, confirmed: true, mode: :eligible_only).call

      expect(result).to be_rejected
      expect(result.reason_code).to eq("token_mode_mismatch")
    end

    it "rejects a missing or unknown mode" do
      plan = EntityMerges::Planner.new(actor: user, context:, source_id: source.id, destination_id: destination.id, mode: :strict).call
      token = EntityMerges::PreviewToken.generate(plan)

      [ nil, :best_effort ].each do |mode|
        result = EntityMerges::Apply.new(actor: user, context:, source_id: source.id, token:, confirmed: true, mode:).call
        expect(result).to be_rejected
        expect(result.reason_code).to eq("invalid_mode")
      end
    end
  end

  describe "eligible_only mode" do
    it "transfers eligible rows and leaves source intact if conflict rows remain" do
      neutral_txn
      monetary_txn

      result = apply(mode: :eligible_only)

      expect(result).to be_applied
      expect(EntityTransaction.where(entity: destination).count).to eq(1)
      expect(EntityTransaction.where(entity: source).count).to eq(1)
      expect(Entity.exists?(source.id)).to be(true)
      expect(destination.reload.cash_transactions_count).to eq(1)
      expect(source.reload.cash_transactions_count).to eq(1)

      op = result.operation
      expect(op.metadata["source_destroyed"]).to be(false)
      expect(op.metadata["remaining_count"]).to eq(1)
    end

    it "rejects a partial apply when eligible and conflict rows enter the same linked graph" do
      neutral_txn
      monetary_txn
      preview = EntityMerges::Planner.new(actor: user, context:, source_id: source.id, destination_id: destination.id, mode: :eligible_only).call
      neutral_txn.update_columns(reference_transactable_type: "CashTransaction", reference_transactable_id: monetary_txn.id)

      result = apply_plan(preview)

      expect(result).to be_rejected
      expect(result.reason_code).to eq("stale_preview")
      expect(EntityTransaction.where(entity: source).count).to eq(2)
      expect(EntityTransaction.where(entity: destination)).to be_empty
    end
  end

  it "acquires its advisory lock with a safely quoted entity-pair key" do
    plan = EntityMerges::Planner.new(actor: user, context:, source_id: source.id, destination_id: destination.id, mode: :strict).call
    token = EntityMerges::PreviewToken.generate(plan)
    service = EntityMerges::Apply.new(actor: user, context:, source_id: source.id, token:, confirmed: true, mode: :strict)
    service.send(:validate_request!)

    expect do
      Entity.transaction { service.send(:acquire_advisory_lock!) }
    end.not_to raise_error
  end
end
