# frozen_string_literal: true

require "rails_helper"

RSpec.describe CategoryMerges::Planner do
  let(:user)        { create(:user) }
  let(:source)      { create(:category, user:, category_name: "SOURCE") }
  let(:destination) { create(:category, user:, category_name: "DESTINATION") }

  def plan(source_id: source.id, destination_id: destination.id)
    described_class.new(actor: user, context: user.main_context, source_id:, destination_id:).call
  end

  # ---------------------------------------------------------------------------
  # Eligible plan
  # ---------------------------------------------------------------------------

  describe "eligible plan" do
    it "is eligible when both categories are owned, active, and not built-in" do
      result = plan
      expect(result).to be_eligible
      expect(result.outcome).to eq(:eligible)
      expect(result.source).to eq(source)
      expect(result.destination).to eq(destination)
    end

    it "produces a non-blank deterministic digest" do
      expect(plan.digest).to match(/\A[a-f0-9]{64}\z/)
    end

    it "produces the same digest for identical inputs" do
      expect(plan.digest).to eq(plan.digest)
    end
  end

  # ---------------------------------------------------------------------------
  # Transaction impact counts
  # ---------------------------------------------------------------------------

  describe "transaction impact counts" do
    let(:context) { user.main_context }
    let(:uba)     { create(:user_bank_account, :random, user:) }

    let(:txn_reassign) do
      create(:cash_transaction, user:, context:, user_bank_account: uba).tap do |txn|
        txn.category_transactions.create!(category: source)
      end
    end

    let(:txn_dedup) do
      create(:cash_transaction, user:, context:, user_bank_account: uba).tap do |txn|
        txn.category_transactions.create!(category: source)
        txn.category_transactions.create!(category: destination)
      end
    end

    before do
      txn_reassign
      txn_dedup
    end

    it "counts reassignable and dedup transactions correctly" do
      result = plan
      expect(result.transaction_reassign_count).to eq(1)
      expect(result.transaction_dedup_count).to    eq(1)
      expect(result.transaction_total_count).to    eq(2)
    end

    it "reports zero counts when source has no transactions" do
      empty_source = create(:category, user:, category_name: "EMPTY SOURCE")
      result = plan(source_id: empty_source.id)
      expect(result.transaction_reassign_count).to eq(0)
      expect(result.transaction_dedup_count).to    eq(0)
    end

    it "blocks the whole merge when the source is allocated in another context" do
      other_context = create(:context, user:, source_context: context)
      other_transaction = create(:cash_transaction, user:, context: other_context, user_bank_account: uba)
      other_transaction.category_transactions.create!(category: source)

      result = plan

      expect(result).to be_conflict
      expect(result).not_to be_eligible
      expect(result.conflict_rows.map(&:reason_code)).to include(:cross_context_allocation)
    end

    it "changes the digest when an affected row is replaced without changing aggregate counts" do
      original_plan = plan
      txn_reassign.category_transactions.find_by!(category: source).destroy!
      replacement = create(:cash_transaction, user:, context:, user_bank_account: uba)
      replacement.category_transactions.create!(category: source)

      expect(plan.digest).not_to eq(original_plan.digest)
      expect(plan.transaction_total_count).to eq(original_plan.transaction_total_count)
    end
  end

  # ---------------------------------------------------------------------------
  # BudgetCategory impact counts
  # ---------------------------------------------------------------------------

  describe "budget_category impact counts" do
    let(:context) { user.main_context }

    let(:budget_reassign) do
      create(:budget, context:, user:, month: 8, year: 2026).tap do |b|
        b.budget_categories.create!(category: source)
      end
    end

    let(:budget_dedup) do
      create(:budget, context:, user:, month: 9, year: 2026).tap do |b|
        b.budget_categories.create!(category: source)
        b.budget_categories.create!(category: destination)
      end
    end

    before do
      budget_reassign
      budget_dedup
    end

    it "counts reassignable and dedup budget_categories correctly" do
      result = plan
      expect(result.budget_reassign_count).to eq(1)
      expect(result.budget_dedup_count).to    eq(1)
      expect(result.budget_total_count).to    eq(2)
    end

    it "blocks a merge that would duplicate another Budget allocation set" do
      create(
        :budget,
        context:,
        user:,
        month: 7,
        year: 2026,
        budget_categories: [ build(:budget_category, category: destination) ]
      )
      create(
        :budget,
        context:,
        user:,
        month: 7,
        year: 2026,
        budget_categories: [ build(:budget_category, category: source) ]
      )

      result = plan

      expect(result).to be_conflict
      expect(result.conflict_rows.map(&:reason_code)).to include(:invalid_final_state)
    end
  end

  describe "allocation policy" do
    let(:context) { user.main_context }

    it "blocks categories owned directly by a Subscription" do
      subscription = create(:subscription, user:, context:)
      subscription.category_transactions.create!(category: source)

      result = plan

      expect(result).to be_conflict
      expect(result.conflict_rows.map(&:reason_code)).to contain_exactly(:subscription_owned_category)
    end

    it "blocks a custom category inherited by a linked transaction" do
      subscription = create(:subscription, user:, context:)
      subscription.category_transactions.create!(category: source)
      transaction = create(:cash_transaction, user:, context:, user_bank_account: create(:user_bank_account, :random, user:), subscription:)
      transaction.category_transactions.find_or_create_by!(category: source)

      result = plan

      expect(result).to be_conflict
      expect(result.conflict_rows.map(&:reason_code)).to all(eq(:subscription_owned_category))
    end

    it "keeps a directly categorized Investment eligible as an ordinary allocation" do
      investment = create(:investment, user:, context:)
      CategoryTransaction.create!(transactable: investment, category: source)

      result = plan

      expect(result).to be_eligible
      expect(result.transfer_rows.map(&:row)).to contain_exactly(CategoryTransaction.find_by!(transactable: investment, category: source))
    end
  end

  # ---------------------------------------------------------------------------
  # Noop
  # ---------------------------------------------------------------------------

  describe "noop" do
    it "returns noop :same_category when source_id equals destination_id" do
      result = plan(source_id: source.id, destination_id: source.id)
      expect(result).to be_noop
      expect(result.reason_code).to eq(:same_category)
    end
  end

  # ---------------------------------------------------------------------------
  # Conflict cases
  # ---------------------------------------------------------------------------

  describe "conflicts" do
    it "returns conflict :context_not_owned for another user's context" do
      other_context = create(:context, user: create(:user, :random))
      result = described_class.new(actor: user, context: other_context, source_id: source.id, destination_id: destination.id).call

      expect(result).to be_conflict
      expect(result.reason_code).to eq(:context_not_owned)
    end

    it "returns conflict :source_not_found when source belongs to another user" do
      other_category = create(:category, :different)
      result = plan(source_id: other_category.id)
      expect(result).to be_conflict
      expect(result.reason_code).to eq(:source_not_found)
    end

    it "returns conflict :destination_not_found when destination belongs to another user" do
      other_category = create(:category, :different)
      result = plan(destination_id: other_category.id)
      expect(result).to be_conflict
      expect(result.reason_code).to eq(:destination_not_found)
    end

    it "returns conflict :source_inactive when source is inactive" do
      source.update_columns(active: false)
      result = plan
      expect(result).to be_conflict
      expect(result.reason_code).to eq(:source_inactive)
    end

    it "returns conflict :destination_inactive when destination is inactive" do
      destination.update_columns(active: false)
      result = plan
      expect(result).to be_conflict
      expect(result.reason_code).to eq(:destination_inactive)
    end

    it "returns conflict :source_protected when source is built-in" do
      source.update_columns(built_in: true)
      result = plan
      expect(result).to be_conflict
      expect(result.reason_code).to eq(:source_protected)
    end

    it "returns conflict :destination_protected when destination is built-in" do
      destination.update_columns(built_in: true)
      result = plan
      expect(result).to be_conflict
      expect(result.reason_code).to eq(:destination_protected)
    end

    it "returns conflict :source_has_children when source has subcategories" do
      create(:category, :random, user:, parent_category: source)
      result = plan
      expect(result).to be_conflict
      expect(result.reason_code).to eq(:source_has_children)
    end

    it "allows merging into a parent category" do
      create(:category, :random, user:, parent_category: destination)
      result = plan
      expect(result).to be_eligible
    end
  end

  # ---------------------------------------------------------------------------
  # Read-only guarantee
  # ---------------------------------------------------------------------------

  it "does not write to the database" do
    uba = create(:user_bank_account, :random, user:)
    txn = create(:cash_transaction, user:, context: user.main_context, user_bank_account: uba)
    txn.category_transactions.create!(category: source)

    expect { plan }.not_to change(CategoryTransaction, :count)
    expect { plan }.not_to change(Category, :count)
  end
end
