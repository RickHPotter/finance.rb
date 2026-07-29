# frozen_string_literal: true

require "rails_helper"

RSpec.describe Audit::Rollback::Adapters::Investment do
  let(:user) { create(:user, :random) }
  let(:admin) { create(:user, :random, admin: true) }
  let(:context) { user.main_context }
  let(:account) { create(:user_bank_account, :random, user:) }
  let(:investment_type) { create(:investment_type, :random) }

  def audited_operation
    operation = nil
    Audit::Operation.run(actor: user, context:, source: :web) do
      yield
      operation = Audit::Operation.ensure_persisted!
    end
    operation
  end

  def apply(operation)
    preview = Audit::Rollback::Preview.new(operation:, actor: admin)
    result = Audit::Rollback::Apply.new(
      operation:,
      actor: admin,
      context: admin.main_context,
      request_id: SecureRandom.uuid,
      token: preview.apply_token,
      confirmed: true
    ).call
    [ preview, result ]
  end

  def create_investment(price: 1_000)
    create(
      :investment,
      user:,
      context:,
      user_bank_account: account,
      investment_type:,
      description: "Long-term investment",
      date: Date.new(2027, 3, 12),
      month: 3,
      year: 2027,
      price:
    )
  end

  def create_piggy_bank_return
    entity = create(:entity, :random, user:)
    source = build(
      :cash_transaction,
      user:,
      context:,
      user_bank_account: account,
      description: "Monthly reserve",
      price: -5_000,
      cash_installments: [ build(:cash_installment, number: 1, price: -5_000, date: Time.zone.now) ],
      category_transactions: [ CategoryTransaction.new(category: user.built_in_category("PIGGY BANK")) ],
      entity_transactions: [ EntityTransaction.new(entity:, price: 0, price_to_be_returned: 0, is_payer: false) ],
      piggy_bank: PiggyBank.new(return_price: 5_000, return_date: 3.months.from_now)
    )
    source.save!
    source.piggy_bank.return_cash_transaction
  end

  it "restores an investment edit and its generated cash projection" do
    investment = PaperTrail.request(enabled: false) { create_investment }
    projection = investment.cash_transaction
    original_comment = projection.comment
    operation = audited_operation { investment.update!(price: 1_400, description: "Temporary investment") }

    preview, result = apply(operation)
    expect(operation.audit_versions.pluck(:item_subtype)).to include("Investment", "CashTransaction", "CashInstallment")
    expect(preview).to have_attributes(state: "previewable")
    expect(result).to have_attributes(status: "applied")
    expect(investment.reload).to have_attributes(price: 1_000, description: "Long-term investment", cash_transaction_id: projection.id)
    expect(projection.reload).to have_attributes(price: 1_000, comment: original_comment)
    expect(projection.cash_installments.sole.price).to eq(1_000)
  end

  it "removes a newly created investment and the generated projection graph" do
    PaperTrail.request(enabled: false) { [ account, investment_type ] }
    investment = nil
    operation = audited_operation { investment = create_investment }
    investment_id = investment.id
    projection_id = investment.cash_transaction_id

    preview, result = apply(operation)
    expect(preview).to have_attributes(state: "previewable")
    expect(result).to have_attributes(status: "applied")
    expect(Investment).not_to exist(investment_id)
    expect(CashTransaction).not_to exist(projection_id)
  end

  it "recreates a destroyed investment with its original projection identity" do
    investment = PaperTrail.request(enabled: false) { create_investment }
    investment_id = investment.id
    projection_id = investment.cash_transaction_id
    operation = audited_operation { investment.destroy! }

    preview, result = apply(operation)
    expect(preview).to have_attributes(state: "previewable")
    expect(result).to have_attributes(status: "applied")
    expect(Investment.find(investment_id).cash_transaction_id).to eq(projection_id)
    expect(CashTransaction).to exist(projection_id)
  end

  it "conflicts before deleting a generated projection with later investment activity" do
    PaperTrail.request(enabled: false) { [ account, investment_type ] }
    investment = nil
    operation = audited_operation { investment = create_investment }
    PaperTrail.request(enabled: false) { create_investment(price: 700) }

    preview = Audit::Rollback::Preview.new(operation:, actor: admin)
    projection_row = preview.rows.find { |row| row.record_type == "CashTransaction" && row.item_id == investment.cash_transaction_id }

    expect(preview).to have_attributes(state: "conflicted")
    expect(projection_row.conflicts.map(&:code)).to include("later_dependencies")
  end

  it "restores a Piggy Bank valuation and its linked return projection" do
    valuation = nil
    return_projection = nil
    PaperTrail.request(enabled: false) do
      return_projection = create_piggy_bank_return
      valuation = create(
        :investment,
        user:,
        context:,
        user_bank_account: account,
        investment_type:,
        description: "Recognized return",
        price: 800,
        date: Date.new(2027, 3, 12),
        month: 3,
        year: 2027,
        piggy_bank_return_cash_transaction: return_projection
      )
    end
    operation = audited_operation { valuation.update!(price: 900) }

    preview, result = apply(operation)

    expect(preview).to have_attributes(state: "previewable")
    expect(result).to have_attributes(status: "applied")
    expect(valuation.reload.price).to eq(800)
    expect(return_projection.reload.price).to eq(5_800)
    expect(return_projection.cash_installments.where(paid: false).sum(:price)).to eq(5_800)
  end
end
