# frozen_string_literal: true

require "rails_helper"

RSpec.describe CategoryMerges::Planner do
  let(:user)        { create(:user) }
  let(:source)      { create(:category, user:, category_name: "SOURCE") }
  let(:destination) { create(:category, user:, category_name: "DESTINATION") }

  def plan(source_id: source.id, destination_id: destination.id)
    described_class.new(actor: user, source_id:, destination_id:).call
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
  end

  # ---------------------------------------------------------------------------
  # BudgetCategory impact counts
  # ---------------------------------------------------------------------------

  describe "budget_category impact counts" do
    let(:context) { user.main_context }

    let(:budget_reassign) do
      create(:budget, context:, user:).tap do |b|
        b.budget_categories.create!(category: source)
      end
    end

    let(:budget_dedup) do
      create(:budget, context:, user:).tap do |b|
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
