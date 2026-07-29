# frozen_string_literal: true

require "rails_helper"

RSpec.describe Audit::Rollback::Adapters::PiggyBank do
  let(:user) { create(:user, :random) }
  let(:admin) { create(:user, :random, admin: true) }
  let(:context) { user.main_context }
  let(:account) { create(:user_bank_account, :random, user:) }
  let(:entity) { create(:entity, :random, user:) }

  def audited_operation
    operation = nil
    Audit::Operation.run(actor: user, context:, source: :web) do
      yield
      operation = Audit::Operation.ensure_persisted!
    end
    operation
  end

  def apply(operation, confirmed: false)
    preview = Audit::Rollback::Preview.new(operation:, actor: admin)
    result = Audit::Rollback::Apply.new(
      operation:,
      actor: admin,
      context: admin.main_context,
      request_id: SecureRandom.uuid,
      token: preview.apply_token,
      confirmed:
    ).call
    [ preview, result ]
  end

  def create_source(with_piggy_bank: true)
    source = build(
      :cash_transaction,
      user:,
      context:,
      user_bank_account: account,
      description: "Monthly reserve",
      price: -5_000,
      cash_installments: [ build(:cash_installment, number: 1, price: -5_000, date: Date.new(2027, 1, 10)) ],
      category_transactions: (with_piggy_bank ? [ CategoryTransaction.new(category: user.built_in_category("PIGGY BANK")) ] : []),
      entity_transactions: [ EntityTransaction.new(entity:, price: 0, price_to_be_returned: 0, is_payer: false) ]
    )
    source.build_piggy_bank(return_price: 5_000, return_date: Date.new(2027, 6, 10)) if with_piggy_bank
    source.save!
    source
  end

  it "restores a Piggy Bank edit and its generated return projection" do
    source = PaperTrail.request(enabled: false) { create_source }
    piggy_bank = source.piggy_bank
    return_projection = piggy_bank.return_cash_transaction
    operation = audited_operation { piggy_bank.update!(return_price: 6_000, return_date: Date.new(2027, 7, 10)) }

    preview, result = apply(operation)
    expect(operation.audit_versions.pluck(:item_subtype)).to include("PiggyBank", "CashTransaction", "CashInstallment")
    expect(preview).to have_attributes(state: "previewable")
    expect(result).to have_attributes(status: "applied")
    expect(piggy_bank.reload).to have_attributes(return_price: 5_000, return_date: Time.zone.local(2027, 6, 10))
    expect(return_projection.reload).to have_attributes(price: 5_000, date: Time.zone.local(2027, 6, 10))
    expect(return_projection.cash_installments.where(paid: false).sum(:price)).to eq(5_000)
  end

  it "removes a newly added Piggy Bank and its return projection" do
    source = PaperTrail.request(enabled: false) { create_source(with_piggy_bank: false) }
    piggy_bank = nil
    operation = audited_operation do
      source.update!(
        category_transactions_attributes: [ { category_id: user.built_in_category("PIGGY BANK").id } ],
        piggy_bank_attributes: { return_price: 5_000, return_date: Date.new(2027, 6, 10) }
      )
      piggy_bank = source.piggy_bank
    end
    piggy_bank_id = piggy_bank.id
    return_projection_id = piggy_bank.return_cash_transaction_id

    preview, result = apply(operation)

    expect(preview).to have_attributes(state: "previewable")
    expect(result).to have_attributes(status: "applied")
    expect(PiggyBank).not_to exist(piggy_bank_id)
    expect(CashTransaction).not_to exist(return_projection_id)
  end

  it "conflicts after later valuation activity changes the return projection" do
    source = PaperTrail.request(enabled: false) { create_source }
    piggy_bank = source.piggy_bank
    operation = audited_operation { piggy_bank.update!(return_price: 5_500) }
    PaperTrail.request(enabled: false) do
      create(
        :investment,
        user:,
        context:,
        user_bank_account: account,
        investment_type: create(:investment_type, :random),
        description: "Later valuation",
        price: 300,
        date: Date.new(2027, 3, 12),
        month: 3,
        year: 2027,
        piggy_bank_return_cash_transaction: piggy_bank.return_cash_transaction
      )
    end

    preview = Audit::Rollback::Preview.new(operation:, actor: admin)

    expect(preview).to have_attributes(state: "conflicted")
    expect(preview.rows.flat_map(&:conflicts).map(&:code)).to include("current_state_changed")
  end
end
