# frozen_string_literal: true

require "rails_helper"

RSpec.describe PiggyBankReconciliations::Preview do
  let(:user) { create(:user, :random) }
  let(:context) { user.main_context }
  let(:account) { create(:user_bank_account, :random, user:) }
  let(:entity) { create(:entity, :random, user:) }
  let!(:investment_type) do
    InvestmentType.find_or_create_by!(investment_type_code: described_class::INVESTMENT_TYPE_CODE) do |type|
      type.investment_type_name_fallback = "Other - Piggy Bank"
      type.built_in = true
    end
  end
  let(:return_transaction) { create_piggy_bank_return }

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

  def create_valuation(price)
    create(
      :investment,
      user:,
      context:,
      user_bank_account: account,
      investment_type:,
      description: "Observed adjustment",
      price:,
      date: Date.new(2026, 9, 15),
      month: 9,
      year: 2026,
      piggy_bank_return_cash_transaction: return_transaction
    )
  end

  def preview(observed_net_cents: 5_500, observed_on: "2026-09-15", target: return_transaction, preview_context: context)
    described_class.new(
      user:,
      context: preview_context,
      return_cash_transaction_id: target.id,
      observed_net_cents:,
      observed_on:
    ).call
  end

  it "calculates a deterministic positive adjustment without writing any record" do
    return_transaction
    first = nil

    expect do
      first = preview
    end.not_to(change { [ Investment.count, AuditOperation.count, AuditVersion.count, return_transaction.reload.updated_at ] })

    second = preview
    expect(first).to have_attributes(
      status: :ready,
      reason_code: nil,
      return_cash_transaction: return_transaction,
      investment_type_id: investment_type.id,
      observed_on: Date.new(2026, 9, 15),
      recorded_remaining_cents: 5_000,
      observed_net_cents: 5_500,
      delta_cents: 500,
      lifetime_recorded_cents: 5_000,
      paid_cents: 0,
      resulting_lifetime_cents: 5_500,
      digest: be_present
    )
    expect(first.digest).to eq(second.digest)
    expect(first).to be_valid
    expect(first).to be_ready
  end

  it "calculates a negative correction from the currently recorded value" do
    create_valuation(800)

    result = preview(observed_net_cents: 5_300)

    expect(result).to have_attributes(
      status: :ready,
      recorded_remaining_cents: 5_800,
      observed_net_cents: 5_300,
      delta_cents: -500,
      lifetime_recorded_cents: 5_800,
      resulting_lifetime_cents: 5_300
    )
  end

  it "returns an explicit no-op when the observation already matches" do
    result = preview(observed_net_cents: 5_000)

    expect(result).to have_attributes(status: :noop, reason_code: nil, delta_cents: 0, digest: be_present)
    expect(result).to be_valid
    expect(result).to be_noop
  end

  it "compares a current bank balance with the unpaid projection after partial withdrawal" do
    paid_installment = return_transaction.cash_installments.sole
    paid_installment.update!(price: 1_000, starting_price: 1_000, paid: true)
    Logic::Manipulation::CashInstallment.new(paid_installment).split_installment(return_transaction.date, 4_000)

    result = preview(observed_net_cents: 4_250)

    expect(result).to have_attributes(
      recorded_remaining_cents: 4_000,
      observed_net_cents: 4_250,
      delta_cents: 250,
      lifetime_recorded_cents: 5_000,
      paid_cents: 1_000,
      resulting_lifetime_cents: 5_250
    )
  end

  it "rejects malformed dates and observed cent values without looking up a target" do
    invalid_dates = [ nil, "", "15/09/2026", "2026-02-30" ]
    invalid_values = [ nil, "", "55.00", "-1", 0, -1, 55.5 ]

    invalid_dates.each do |value|
      expect(preview(observed_on: value)).to have_attributes(status: :invalid, reason_code: :invalid_observation_date, digest: nil)
    end
    invalid_values.each do |value|
      expect(preview(observed_net_cents: value)).to have_attributes(status: :invalid, reason_code: :invalid_observed_value, digest: nil)
    end
  end

  it "does not resolve returns outside the supplied user and context" do
    other_user = create(:user, :random)
    other_return = create_piggy_bank_return(owner: other_user, transaction_context: other_user.main_context)
    other_context = create(:context, user:)

    expect(preview(target: other_return)).to have_attributes(status: :invalid, reason_code: :return_not_found)
    expect(preview(preview_context: other_context)).to have_attributes(status: :invalid, reason_code: :return_not_found)
  end

  it "rejects an ordinary cash transaction and a settled Piggy Bank return" do
    ordinary = create(:cash_transaction, :random, user:, context:, user_bank_account: account)

    expect(preview(target: ordinary)).to have_attributes(status: :invalid, reason_code: :invalid_return)

    return_transaction.cash_installments.update_all(paid: true)
    return_transaction.update_column(:paid, true)
    expect(preview).to have_attributes(status: :invalid, reason_code: :settled_return)
  end

  it "reports inconsistent projection arithmetic as graph issues" do
    return_transaction.update_column(:price, 5_100)

    result = preview

    expect(result).to have_attributes(status: :invalid, reason_code: :invalid_return_graph, digest: nil)
    expect(result.issues).to include(:return_total_mismatch)
  end

  it "fails clearly when the canonical Piggy Bank Investment type is unavailable" do
    allow(InvestmentType).to receive(:find_by).with(investment_type_code: described_class::INVESTMENT_TYPE_CODE).and_return(nil)

    expect(preview).to have_attributes(status: :invalid, reason_code: :missing_investment_configuration, digest: nil)
  end

  it "changes the digest when financial graph state or observation input changes" do
    original = preview
    changed_observation = preview(observed_net_cents: 5_501)
    create_valuation(100)
    changed_graph = preview(observed_net_cents: 5_600)

    expect(changed_observation.digest).not_to eq(original.digest)
    expect(changed_graph.digest).not_to eq(changed_observation.digest)
  end
end
