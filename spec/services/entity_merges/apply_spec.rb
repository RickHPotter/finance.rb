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
    plan = EntityMerges::Planner.new(actor: user, source_id: source.id, destination_id: destination.id, mode:).call
    token = EntityMerges::PreviewToken.generate(plan)
    EntityMerges::Apply.new(actor: user, context:, token:, confirmed: true, mode:).call
  end

  describe "strict mode" do
    it "transfers neutral rows and destroys source" do
      neutral_txn
      result = apply(mode: :strict)

      expect(result).to be_applied
      expect(EntityTransaction.where(entity: destination).count).to eq(1)
      expect(Entity.exists?(source.id)).to be(false)

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

      op = result.operation
      expect(op.metadata["source_destroyed"]).to be(false)
      expect(op.metadata["remaining_count"]).to eq(1)
    end
  end
end
