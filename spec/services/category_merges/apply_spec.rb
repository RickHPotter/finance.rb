# frozen_string_literal: true

require "rails_helper"

RSpec.describe CategoryMerges::Apply do
  let(:user)        { create(:user) }
  let(:context)     { user.main_context }
  let(:source)      { create(:category, user:, category_name: "SOURCE") }
  let(:destination) { create(:category, user:, category_name: "DESTINATION") }
  let(:uba)         { create(:user_bank_account, :random, user:) }

  def valid_token(source_id: source.id, destination_id: destination.id)
    plan = CategoryMerges::Planner.new(actor: user, source_id:, destination_id:).call
    CategoryMerges::PreviewToken.generate(plan)
  end

  def apply(token:, actor: user, confirmed: true)
    described_class.new(actor:, context:, token:, confirmed:).call
  end

  # ---------------------------------------------------------------------------
  # Successful merge
  # ---------------------------------------------------------------------------

  describe "successful merge" do
    let!(:txn_reassign) do
      create(:cash_transaction, user:, context:, user_bank_account: uba).tap do |txn|
        txn.category_transactions.create!(category: source)
      end
    end

    let!(:txn_dedup) do
      create(:cash_transaction, user:, context:, user_bank_account: uba).tap do |txn|
        txn.category_transactions.create!(category: source)
        txn.category_transactions.create!(category: destination)
      end
    end

    let!(:budget_reassign) do
      create(:budget, context:, user:).tap { |b| b.budget_categories.create!(category: source) }
    end

    let!(:budget_dedup) do
      create(:budget, context:, user:).tap do |b|
        b.budget_categories.create!(category: source)
        b.budget_categories.create!(category: destination)
      end
    end

    let(:token) { valid_token }
    let(:result) { apply(token:) }

    it "returns status :applied" do
      expect(result.status).to eq(:applied)
    end

    it "destroys the source category" do
      expect { result }.to change { Category.exists?(source.id) }.from(true).to(false)
    end

    it "preserves the destination category" do
      result
      expect(destination.reload).to be_persisted
    end

    it "reassigns the non-dedup CategoryTransaction to destination" do
      result
      expect(txn_reassign.category_transactions.reload.map(&:category_id)).to include(destination.id)
    end

    it "drops the dedup CategoryTransaction row on source" do
      expect { result }.to change {
        CategoryTransaction.where(category: source).count
      }.to(0)
    end

    it "retains exactly one CategoryTransaction for dedup transactable" do
      result
      ct_count = txn_dedup.category_transactions.reload.count
      ct_ids   = txn_dedup.category_transactions.reload.map(&:category_id)
      expect(ct_count).to eq(1)
      expect(ct_ids).to eq([ destination.id ])
    end

    it "reassigns the non-dedup BudgetCategory to destination" do
      result
      expect(budget_reassign.budget_categories.reload.map(&:category_id)).to include(destination.id)
    end

    it "drops the dedup BudgetCategory on source" do
      result
      expect(BudgetCategory.where(category: source).count).to eq(0)
    end

    it "removes the source BudgetCategory for dedup budget" do
      result
      expect(BudgetCategory.where(budget: budget_dedup, category: source).count).to eq(0)
    end

    it "retains the destination BudgetCategory for dedup budget" do
      result
      expect(BudgetCategory.where(budget: budget_dedup, category: destination).count).to eq(1)
    end

    it "refreshes the destination counter-caches" do
      result
      dest = destination.reload
      expect(dest.cash_transactions_count).to be >= 1
    end

    it "persists an AuditOperation with category_merge metadata" do
      expect { result }.to change(AuditOperation, :count).by(1)
      op = result.operation
      expect(op.metadata["category_merge"]).to be(true)
      expect(op.metadata["source_id"]).to eq(source.id)
      expect(op.metadata["destination_id"]).to eq(destination.id)
    end
  end

  # ---------------------------------------------------------------------------
  # Rejection cases
  # ---------------------------------------------------------------------------

  describe "rejection" do
    it "rejects when confirmation is missing" do
      result = apply(token: valid_token, confirmed: false)
      expect(result.status).to eq(:rejected)
      expect(result.reason_code).to eq("confirmation_required")
    end

    it "rejects with an invalid token" do
      result = apply(token: "bogus.token.value")
      expect(result.status).to eq(:rejected)
      expect(result.reason_code).to eq("invalid_token")
    end

    it "rejects when the token belongs to a different actor" do
      other_user = create(:user, :different)
      result = apply(token: valid_token, actor: other_user)
      expect(result.status).to eq(:rejected)
      expect(result.reason_code).to eq("token_actor_mismatch")
    end

    it "rejects with stale_preview when the plan digest changed after token generation" do
      token = valid_token
      # Invalidate the plan by deactivating destination between preview and apply
      destination.update_columns(active: false)
      result = apply(token:)
      expect(result.status).to eq(:rejected)
      expect(result.reason_code).to eq("stale_preview")
    end

    it "rejects with merge_ineligible when source is gone between preview and apply" do
      token = valid_token
      # Force a digest match but ineligible plan by destroying source between token and apply
      # (Achieve this by stubbing fresh_plan to return a noop)
      allow_any_instance_of(CategoryMerges::Planner).to receive(:call).and_wrap_original do |original, *args|
        plan = original.call(*args)
        # Simulate digest match but conflict outcome
        allow(plan).to receive(:digest).and_return(CategoryMerges::PreviewToken.verify(token)["digest"])
        allow(plan).to receive(:eligible?).and_return(false)
        plan
      end

      result = apply(token:)
      expect(result.status).to eq(:rejected)
      expect(result.reason_code).to eq("merge_ineligible")
    end
  end

  # ---------------------------------------------------------------------------
  # No writes on rejection
  # ---------------------------------------------------------------------------

  it "does not modify the database when rejected" do
    expect do
      apply(token: "bad", confirmed: false)
    end.not_to change(AuditOperation, :count)

    expect(Category.exists?(source.id)).to be(true)
  end
end
