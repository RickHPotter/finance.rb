# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Piggy bank reconciliations" do
  let(:user) { create(:user, :random) }
  let(:context) { user.main_context }
  let(:account) { create(:user_bank_account, :random, user:) }
  let(:entity) { create(:entity, :random, user:) }
  let!(:investment_type) do
    InvestmentType.find_or_create_by!(investment_type_code: PiggyBankReconciliations::Preview::INVESTMENT_TYPE_CODE) do |type|
      type.investment_type_name_fallback = "Other - Piggy Bank"
      type.built_in = true
    end
  end
  let(:return_transaction) { create_piggy_bank_return }

  before { sign_in user }

  def create_piggy_bank_return(owner: user, transaction_context: context, price: 5_000)
    owner_account = owner == user ? account : create(:user_bank_account, :random, user: owner)
    owner_entity = owner == user ? entity : create(:entity, :random, user: owner)
    source = build(
      :cash_transaction,
      user: owner,
      context: transaction_context,
      user_bank_account: owner_account,
      description: "Observed reserve",
      price: -price,
      cash_installments: [ build(:cash_installment, number: 1, price: -price, date: Date.new(2026, 9, 1)) ],
      category_transactions: [ CategoryTransaction.new(category: owner.built_in_category("PIGGY BANK")) ],
      entity_transactions: [ EntityTransaction.new(entity: owner_entity, price: 0, price_to_be_returned: 0, is_payer: false) ],
      piggy_bank: PiggyBank.new(return_price: price, return_date: Date.new(2026, 12, 1))
    )
    source.save!
    source.piggy_bank.return_cash_transaction
  end

  def preview_plan(observed_net_cents: 5_500, observed_on: "2026-09-15", target: return_transaction)
    PiggyBankReconciliations::Preview.new(
      user:,
      context:,
      return_cash_transaction_id: target.id,
      observed_net_cents:,
      observed_on:
    ).call
  end

  describe "GET /cash_transactions/:cash_transaction_id/piggy_bank_reconciliation/new" do
    it "renders 200 OK with the form and current baseline/remaining values for an open return" do
      get new_cash_transaction_piggy_bank_reconciliation_path(return_transaction)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t("piggy_bank_reconciliations.form.title"))
      expect(response.body).to include(return_transaction.description)
      expect(response.body).to include("R$ 50.00")
      expect(response.body).to include("piggy_bank_reconciliation_observed_net")
      expect(response.body).to include("piggy_bank_reconciliation_observed_on")
    end

    it "returns 404 for a transaction belonging to another user" do
      other_user = create(:user, :random)
      foreign_return = create_piggy_bank_return(owner: other_user, transaction_context: other_user.main_context)

      get new_cash_transaction_piggy_bank_reconciliation_path(foreign_return)
      expect(response).to have_http_status(:not_found)
    end

    it "redirects to return with alert when the transaction is not a Piggy Bank return" do
      ordinary = create(:cash_transaction, user:, context:, user_bank_account: account, price: 1_000)

      get new_cash_transaction_piggy_bank_reconciliation_path(ordinary)
      expect(response).to redirect_to(cash_transaction_path(ordinary))
      expect(flash[:alert]).to eq(I18n.t("piggy_bank_reconciliations.reasons.invalid_return"))
    end

    it "redirects to return with alert when the return is already fully settled" do
      return_transaction.cash_installments.first.update!(paid: true)

      get new_cash_transaction_piggy_bank_reconciliation_path(return_transaction)
      expect(response).to redirect_to(cash_transaction_path(return_transaction))
      expect(flash[:alert]).to eq(I18n.t("piggy_bank_reconciliations.reasons.settled_return"))
    end
  end

  describe "POST /cash_transactions/:cash_transaction_id/piggy_bank_reconciliation/preview" do
    let(:valid_params) do
      {
        observed_on: "2026-09-15",
        observed_net: "55.00",
        description: "Bank statement snapshot"
      }
    end

    it "calculates the preview delta without database writes via HTML" do
      expect do
        post preview_cash_transaction_piggy_bank_reconciliation_path(return_transaction), params: valid_params
      end.not_to change(Investment, :count)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t("piggy_bank_reconciliations.preview.title"))
      expect(response.body).to include("+ R$ 5.00")
      expect(response.body).to include("apply_piggy_bank_reconciliation")
    end

    it "replaces the preview frame and clears notifications via Turbo Stream" do
      post preview_cash_transaction_piggy_bank_reconciliation_path(return_transaction),
           params: valid_params,
           headers: { "Accept" => "text/vnd.turbo-stream.html" }

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include('turbo-stream action="replace" target="piggy_bank_reconciliation_preview"')
      expect(response.body).to include('turbo-stream action="update" target="notification"')
      expect(response.body).to include("+ R$ 5.00")
      expect(response.body).to include(I18n.t("piggy_bank_reconciliations.preview.ready_badge"))
    end

    it "identifies zero-delta noop in preview" do
      post preview_cash_transaction_piggy_bank_reconciliation_path(return_transaction),
           params: { observed_on: "2026-09-15", observed_net: "50.00" },
           headers: { "Accept" => "text/vnd.turbo-stream.html" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t("piggy_bank_reconciliations.preview.noop_badge"))
      expect(response.body).to include(I18n.t("piggy_bank_reconciliations.form.apply_noop_button"))
    end

    it "returns 422 with stacked notifications when observed net value is invalid" do
      post preview_cash_transaction_piggy_bank_reconciliation_path(return_transaction),
           params: { observed_on: "2026-09-15", observed_net: "0" },
           headers: { "Accept" => "text/vnd.turbo-stream.html" }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('turbo-stream action="update" target="notification"')
      expect(response.body).to include('turbo-stream action="append" target="notification"')
      expect(response.body).to include(I18n.t("piggy_bank_reconciliations.reasons.invalid_observed_value"))
      expect(response.body).to include('turbo-stream action="update" target="piggy_bank_reconciliation_preview"')
    end

    it "returns 422 via HTML retaining submitted inputs when observation date is invalid" do
      post preview_cash_transaction_piggy_bank_reconciliation_path(return_transaction),
           params: { observed_on: "invalid-date", observed_net: "55.00" }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("55.00")
      expect(response.body).to include(I18n.t("piggy_bank_reconciliations.reasons.invalid_observation_date"))
    end

    it "returns 404 for a foreign transaction" do
      other_user = create(:user, :random)
      foreign_return = create_piggy_bank_return(owner: other_user, transaction_context: other_user.main_context)

      post preview_cash_transaction_piggy_bank_reconciliation_path(foreign_return), params: valid_params
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /cash_transactions/:cash_transaction_id/piggy_bank_reconciliation (apply)" do
    let(:plan) { preview_plan(observed_net_cents: 5_500, observed_on: "2026-09-15") }
    let(:apply_params) do
      {
        observed_on: plan.observed_on.iso8601,
        observed_net: plan.observed_net_cents,
        digest: plan.digest,
        description: "Verified balance"
      }
    end

    it "applies a positive delta atomically and redirects 303 to return with notice" do
      expect do
        post cash_transaction_piggy_bank_reconciliation_path(return_transaction), params: apply_params
      end.to change(Investment, :count).by(1)

      expect(response).to redirect_to(cash_transaction_path(return_transaction))
      expect(response).to have_http_status(:see_other)
      expect(flash[:notice]).to eq(I18n.t("piggy_bank_reconciliations.applied"))

      investment = Investment.last
      expect(investment.price).to eq(500)
      expect(investment.piggy_bank_return_cash_transaction_id).to eq(return_transaction.id)
      expect(investment.date.to_date).to eq(Date.new(2026, 9, 15))

      return_transaction.reload
      expect(return_transaction.price).to eq(5_500)
      expect(return_transaction.starting_price).to eq(5_500)
      expect(return_transaction.cash_installments.first.price).to eq(5_500)
    end

    it "applies a negative delta atomically" do
      neg_plan = preview_plan(observed_net_cents: 4_500, observed_on: "2026-09-15")

      expect do
        post cash_transaction_piggy_bank_reconciliation_path(return_transaction), params: {
          observed_on: neg_plan.observed_on.iso8601,
          observed_net: neg_plan.observed_net_cents,
          digest: neg_plan.digest
        }
      end.to change(Investment, :count).by(1)

      expect(response).to redirect_to(cash_transaction_path(return_transaction))
      expect(Investment.last.price).to eq(-500)

      return_transaction.reload
      expect(return_transaction.price).to eq(4_500)
      expect(return_transaction.cash_installments.first.price).to eq(4_500)
    end

    it "handles zero delta as a successful no-op redirect without creating an Investment" do
      noop_plan = preview_plan(observed_net_cents: 5_000, observed_on: "2026-09-15")

      expect do
        post cash_transaction_piggy_bank_reconciliation_path(return_transaction), params: {
          observed_on: noop_plan.observed_on.iso8601,
          observed_net: noop_plan.observed_net_cents,
          digest: noop_plan.digest
        }
      end.not_to change(Investment, :count)

      expect(response).to redirect_to(cash_transaction_path(return_transaction))
      expect(response).to have_http_status(:see_other)
      expect(flash[:notice]).to eq(I18n.t("piggy_bank_reconciliations.noop"))
    end

    it "rejects stale preview when the digest does not match and commits zero writes" do
      expect do
        post cash_transaction_piggy_bank_reconciliation_path(return_transaction),
             params: apply_params.merge(digest: "stale_digest_1234"),
             headers: { "Accept" => "text/vnd.turbo-stream.html" }
      end.not_to change(Investment, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include(I18n.t("piggy_bank_reconciliations.reasons.stale_preview"))
      expect(return_transaction.reload.price).to eq(5_000)
    end

    it "rejects double submission on the second apply without duplicate investment" do
      post cash_transaction_piggy_bank_reconciliation_path(return_transaction), params: apply_params
      expect(response).to redirect_to(cash_transaction_path(return_transaction))
      expect(Investment.count).to eq(1)

      # Second submission with same digest is stale because return graph changed
      post cash_transaction_piggy_bank_reconciliation_path(return_transaction), params: apply_params
      expect(response).to have_http_status(:unprocessable_content)
      expect(Investment.count).to eq(1)
    end

    it "preserves paid history on partial withdrawal and calculates delta against unpaid remainder" do
      # Simulate a 20.00 partial withdrawal
      return_transaction.cash_installments.first.update!(price: 2_000, paid: true)
      return_transaction.cash_installments.create!(
        number: 2,
        order_id: 2,
        price: 3_000,
        date: Date.new(2026, 12, 1),
        paid: false
      )

      partial_plan = preview_plan(observed_net_cents: 3_500, observed_on: "2026-09-15")
      expect(partial_plan.delta_cents).to eq(500)

      post cash_transaction_piggy_bank_reconciliation_path(return_transaction), params: {
        observed_on: partial_plan.observed_on.iso8601,
        observed_net: partial_plan.observed_net_cents,
        digest: partial_plan.digest
      }

      expect(response).to redirect_to(cash_transaction_path(return_transaction))
      return_transaction.reload
      paid_inst = return_transaction.cash_installments.find_by(number: 1)
      unpaid_inst = return_transaction.cash_installments.find_by(number: 2)

      expect(paid_inst.price).to eq(2_000)
      expect(paid_inst.paid?).to be(true)
      expect(unpaid_inst.price).to eq(3_500)
      expect(unpaid_inst.paid?).to be(false)
      expect(return_transaction.price).to eq(5_500)
    end

    it "respects a safe custom return_to destination" do
      target_url = cash_transactions_path(all_month_years: true)

      post cash_transaction_piggy_bank_reconciliation_path(return_transaction), params: apply_params.merge(return_to: target_url)
      expect(response).to redirect_to(cash_transaction_path(return_transaction))
    end

    it "returns 404 if return transaction belongs to another user" do
      other_user = create(:user, :random)
      foreign_return = create_piggy_bank_return(owner: other_user, transaction_context: other_user.main_context)
      foreign_plan = preview_plan(target: foreign_return)

      post cash_transaction_piggy_bank_reconciliation_path(foreign_return), params: {
        observed_on: "2026-09-15",
        observed_net: 5_500,
        digest: foreign_plan.digest
      }
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "Cash transactions detail surface integration (Views::CashTransactions::Show)" do
    it "renders the Piggy Bank return section and reconcile action button for an open return" do
      get cash_transaction_path(return_transaction)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t("piggy_banks.return_section.title"))
      expect(response.body).to include(I18n.t("piggy_banks.return_section.baseline"))
      expect(response.body).to include(I18n.t("piggy_banks.return_section.remaining"))
      expect(response.body).to include(I18n.t("piggy_banks.actions.reconcile_valuation"))
      expect(response.body).to include(new_cash_transaction_piggy_bank_reconciliation_path(return_transaction))
    end

    it "does not offer reconcile valuation action for a settled return and shows settled notice" do
      return_transaction.cash_installments.first.update!(paid: true)

      get cash_transaction_path(return_transaction)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t("piggy_banks.settled_notice"))
      expect(response.body).not_to include(new_cash_transaction_piggy_bank_reconciliation_path(return_transaction))
    end

    it "does not render the Piggy Bank return section on an ordinary cash transaction" do
      ordinary = create(:cash_transaction, user:, context:, user_bank_account: account, price: 1_000)

      get cash_transaction_path(ordinary)

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include(I18n.t("piggy_banks.return_section.title"))
    end
  end
end
