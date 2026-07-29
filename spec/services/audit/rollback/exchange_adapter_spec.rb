# frozen_string_literal: true

require "rails_helper"

RSpec.describe Audit::Rollback::Adapters::Exchange do
  let(:user) { create(:user, :random) }
  let(:admin) { create(:user, :random, admin: true) }
  let(:context) { user.main_context }

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

  def create_exchange(price: 1_000)
    source = create(
      :cash_transaction,
      user:,
      context:,
      description: "Loan source",
      price: -price
    )
    entity_transaction = create(
      :entity_transaction,
      transactable: source,
      entity: create(:entity, :random, user:),
      is_payer: true,
      price: -price,
      price_to_be_returned: -price
    )
    create(
      :exchange,
      entity_transaction:,
      exchange_type: :monetary,
      number: 1,
      price:,
      starting_price: price,
      date: Date.new(2027, 4, 10),
      month: 4,
      year: 2027
    )
  end

  it "restores a monetary exchange and its generated return projection" do
    exchange = PaperTrail.request(enabled: false) { create_exchange }
    projection = exchange.cash_transaction
    operation = audited_operation { exchange.update!(price: 1_400, starting_price: 1_400) }

    preview, result = apply(operation)

    expect(operation.audit_versions.pluck(:item_subtype)).to include("Exchange", "CashTransaction", "CashInstallment")
    expect(preview).to have_attributes(state: "previewable")
    expect(result).to have_attributes(status: "applied")
    expect(exchange.reload).to have_attributes(price: 1_000, starting_price: 1_000, cash_transaction_id: projection.id)
    expect(projection.reload.price).to eq(1_000)
    expect(projection.cash_installments.sum(:price)).to eq(1_000)
  end

  it "removes a newly created exchange and its generated projection" do
    PaperTrail.request(enabled: false) do
      user
      context
    end
    exchange = nil
    operation = audited_operation { exchange = create_exchange }
    exchange_id = exchange.id
    projection_id = exchange.cash_transaction_id

    preview, result = apply(operation)

    expect(preview).to have_attributes(state: "previewable")
    expect(result).to have_attributes(status: "applied")
    expect(Exchange).not_to exist(exchange_id)
    expect(CashTransaction).not_to exist(projection_id)
  end

  it "conflicts when later exchanges change the shared projection" do
    exchange = PaperTrail.request(enabled: false) { create_exchange }
    operation = audited_operation { exchange.update!(price: 1_200, starting_price: 1_200) }
    PaperTrail.request(enabled: false) do
      create(
        :exchange,
        entity_transaction: exchange.entity_transaction,
        exchange_type: :monetary,
        number: 2,
        price: 500,
        starting_price: 500,
        date: Date.new(2027, 5, 10),
        month: 5,
        year: 2027
      )
    end

    preview = Audit::Rollback::Preview.new(operation:, actor: admin)

    expect(preview).to have_attributes(state: "conflicted")
    expect(preview.rows.flat_map(&:conflicts).map(&:code)).to include("current_state_changed")
  end
end
