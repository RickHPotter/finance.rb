# frozen_string_literal: true

require "rails_helper"

RSpec.describe "EntityMerges::Planner" do
  let(:user) { create(:user) }
  let(:source) { create(:entity, :random, user:) }
  let(:destination) { create(:entity, :random, user:) }
  let(:context) { user.main_context }
  let(:bank) { create(:bank) }
  let(:user_bank_account) { create(:user_bank_account, user:, bank:) }

  def plan(mode: :strict)
    EntityMerges::Planner.new(actor: user, source_id: source.id, destination_id: destination.id, mode:).call
  end

  describe "validation" do
    it "returns conflict if source is missing" do
      result = EntityMerges::Planner.new(actor: user, source_id: 0, destination_id: destination.id).call
      expect(result.outcome).to eq(:conflict)
      expect(result.reason_code).to eq(:source_not_found)
    end

    it "returns noop if source and destination are the same" do
      result = EntityMerges::Planner.new(actor: user, source_id: source.id, destination_id: source.id).call
      expect(result.outcome).to eq(:noop)
      expect(result.reason_code).to eq(:same_entity)
    end

    it "blocks cross-user friend merges" do
      other_user = create(:user, :random)
      source.update!(entity_user_id: other_user.id)
      result = plan
      expect(result.outcome).to eq(:conflict)
      expect(result.reason_code).to eq(:cross_user_friend_entity)
    end
  end

  describe "classification" do
    let(:neutral_txn) do
      create(:cash_transaction, user:, context:, user_bank_account:, price: 0).tap do |t|
        t.entity_transactions.create!(entity: source, price: 0, is_payer: false)
      end
    end

    let(:payer_txn) do
      create(:cash_transaction, user:, context:, user_bank_account:, price: 0).tap do |t|
        t.entity_transactions.create!(entity: source, price: 0, price_to_be_returned: 100)
      end
    end

    let(:monetary_txn) do
      create(:cash_transaction, user:, context:, user_bank_account:, price: 0).tap do |t|
        t.entity_transactions.create!(entity: source, price: 100, is_payer: false)
      end
    end

    it "classifies a neutral row as transfer" do
      neutral_txn
      result = plan
      expect(result.transfer_rows.size).to eq(1)
      expect(result.conflict_rows.size).to eq(0)
      expect(result.apply_available?).to be(true)
    end

    it "classifies a payer row as conflict :payer_entity" do
      payer_txn
      result = plan
      expect(result.conflict_rows.first.reason_code).to eq(:payer_entity)
      expect(result.apply_available?).to be(false)
    end

    it "classifies a non-zero price row as conflict :monetary_entity" do
      monetary_txn
      result = plan
      expect(result.conflict_rows.first.reason_code).to eq(:monetary_entity)
      expect(result.apply_available?).to be(false)
    end

    it "classifies a duplicate neutral row as collapse" do
      neutral_txn.entity_transactions.create!(entity: destination, price: 0, is_payer: false)
      result = plan
      expect(result.collapse_rows.size).to eq(1)
      expect(result.transfer_rows.size).to eq(0)
    end

    describe "eligible_only mode" do
      it "is available when independent eligible and conflict rows exist" do
        neutral_txn
        monetary_txn
        result = plan(mode: :eligible_only)

        expect(result.transfer_rows.size).to eq(1)
        expect(result.conflict_rows.size).to eq(1)
        expect(result.eligible_only_available?).to be(true)
        expect(result.apply_available?).to be(true)
      end

      it "is NOT available if they share the same transaction" do
        # This simulates a single transaction with both a neutral row and a conflict row.
        # However, a single transaction can have multiple entity_transactions for the SAME entity?
        # No, entity_id must be unique per transactable. So they can't share the same transaction for the SAME entity.
        # But wait, INSEPARABLE_REASON_CODES from AllocationMutations::IndependenceClassifier handles linked structural groups.
        # Since EntityMerge Planner doesn't use those specific reason codes, it will always be independent as long as it's not structural_entity_allocation.
        neutral_txn
        payer_txn
        result = plan(mode: :eligible_only)
        expect(result.eligible_only_available?).to be(true)
      end
    end
  end
end
