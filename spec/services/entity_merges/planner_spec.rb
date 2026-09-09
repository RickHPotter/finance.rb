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
    EntityMerges::Planner.new(actor: user, context:, source_id: source.id, destination_id: destination.id, mode:).call
  end

  describe "validation" do
    it "rejects a missing or unknown mode" do
      missing = EntityMerges::Planner.new(actor: user, context:, source_id: source.id, destination_id: destination.id, mode: nil).call
      unknown = EntityMerges::Planner.new(actor: user, context:, source_id: source.id, destination_id: destination.id, mode: :best_effort).call

      expect(missing).to have_attributes(outcome: :conflict, reason_code: :invalid_mode)
      expect(unknown).to have_attributes(outcome: :conflict, reason_code: :invalid_mode)
    end

    it "returns conflict if source is missing" do
      result = EntityMerges::Planner.new(actor: user, context:, source_id: 0, destination_id: destination.id, mode: :strict).call
      expect(result.outcome).to eq(:conflict)
      expect(result.reason_code).to eq(:source_not_found)
    end

    it "returns noop if source and destination are the same" do
      result = EntityMerges::Planner.new(actor: user, context:, source_id: source.id, destination_id: source.id, mode: :strict).call
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

    it "allows friend-backed entities that resolve to the same canonical user" do
      friend = create(:user, :random)
      source.update!(entity_user: friend)
      destination.update!(entity_user: friend)

      result = plan

      expect(source.reload.entity_user_id).to eq(friend.id)
      expect(destination.reload.entity_user_id).to eq(friend.id)
      expect(result.apply_available?).to be(true)
    end

    it "rejects another user's context" do
      other_context = create(:context, user: create(:user, :random))
      result = EntityMerges::Planner.new(actor: user, context: other_context, source_id: source.id, destination_id: destination.id, mode: :strict).call

      expect(result).to have_attributes(outcome: :conflict, reason_code: :context_not_owned)
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

    it "refuses to collapse a neutral source onto a non-neutral destination row" do
      neutral_txn.entity_transactions.create!(entity: destination, price: 100, price_to_be_returned: 0, is_payer: false)

      result = plan

      expect(result.collapse_rows).to be_empty
      expect(result.conflict_rows.first).to have_attributes(reason_code: :same_transaction_conflict)
      expect(result.conflict_rows.first.details[:destination_reasons]).to contain_exactly(:price)
    end

    it "reports the complete same-owner conflict when both rows are non-neutral" do
      transaction = monetary_txn
      transaction.entity_transactions.create!(entity: destination, price: 0, price_to_be_returned: 100, is_payer: true)

      result = plan

      expect(result.conflict_rows.first).to have_attributes(reason_code: :same_transaction_conflict)
      expect(result.conflict_rows.first.details[:source_reasons]).to contain_exactly(:price)
      expect(result.conflict_rows.first.details[:destination_reasons]).to contain_exactly(:payer, :return)
    end

    it "reports generated, exchange, and Piggy Bank structures explicitly" do
      structures = {
        generated_family_entity: [ "Investment", user.built_in_category("INVESTMENT") ],
        exchange_entity: [ nil, user.built_in_category("EXCHANGE") ],
        piggy_bank_entity: [ nil, user.built_in_category("PIGGY BANK") ]
      }

      structures.each do |reason_code, (cash_transaction_type, category)|
        owner = create(:cash_transaction, user:, context:, user_bank_account:, price: 0, cash_transaction_type:)
        owner.category_transactions.create!(category:)
        owner.entity_transactions.create!(entity: source, price: 0, price_to_be_returned: 0, is_payer: false)

        result = plan

        expect(result.conflict_rows.map(&:reason_code)).to include(reason_code)
        owner.entity_transactions.find_by!(entity: source).destroy!
      end
    end

    it "blocks an entity allocation owned directly by a Subscription" do
      subscription = create(:subscription, user:, context:)
      subscription.entity_transactions.create!(entity: source, price: 0, price_to_be_returned: 0, is_payer: false)

      result = plan

      expect(result.conflict_rows.map(&:reason_code)).to contain_exactly(:subscription_owned_entity)
    end

    it "blocks a merge that would duplicate another Budget allocation set" do
      create(
        :budget,
        user:,
        context:,
        month: 7,
        year: 2026,
        budget_categories: [],
        budget_entities: [ build(:budget_entity, entity: destination) ]
      )
      create(
        :budget,
        user:,
        context:,
        month: 7,
        year: 2026,
        budget_categories: [],
        budget_entities: [ build(:budget_entity, entity: source) ]
      )

      result = plan

      expect(result.conflict_rows.map(&:reason_code)).to include(:invalid_final_state)
      expect(result.apply_available?).to be(false)
    end

    it "blocks the whole merge when the source is allocated in another context" do
      neutral_txn
      other_context = create(:context, user:, source_context: context)
      other_transaction = create(:cash_transaction, user:, context: other_context, user_bank_account:, price: 0)
      other_transaction.entity_transactions.create!(entity: source, price: 0, is_payer: false)

      result = plan(mode: :eligible_only)

      expect(result.conflict_rows.map(&:reason_code)).to include(:cross_context_allocation)
      expect(result.apply_available?).to be(false)
      expect(result.eligible_only_available?).to be(false)
    end

    it "changes the digest when an affected row is replaced without changing aggregate counts" do
      neutral_txn
      original_plan = plan
      neutral_txn.entity_transactions.find_by!(entity: source).destroy!
      replacement = create(:cash_transaction, user:, context:, user_bank_account:, price: 0)
      replacement.entity_transactions.create!(entity: source, price: 0, is_payer: false)

      expect(plan.digest).not_to eq(original_plan.digest)
      expect(plan.transfer_rows.size).to eq(original_plan.transfer_rows.size)
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
        neutral_txn.update_columns(reference_transactable_type: "CashTransaction", reference_transactable_id: payer_txn.id)

        result = plan(mode: :eligible_only)

        expect(result.eligible_only_available?).to be(false)
        expect(result.apply_available?).to be(false)
      end
    end
  end
end
