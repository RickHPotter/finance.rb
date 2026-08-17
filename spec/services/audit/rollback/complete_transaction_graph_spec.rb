# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Complete transaction graph rollback" do
  let(:user) { create(:user, :random) }
  let(:admin) { create(:user, :random, admin: true) }
  let(:context) { user.main_context }
  let(:account) { create(:user_bank_account, :random, user:, bank: create(:bank, :random)) }

  def audited_operation(source: :web)
    operation = nil
    Audit::Operation.run(actor: user, context:, source:) do
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

  it "restores a transaction with a canonical cross-transaction reference" do
    source = PaperTrail.request(enabled: false) { create(:cash_transaction, user:, context:, user_bank_account: account, description: "Reference root") }
    referenced = PaperTrail.request(enabled: false) do
      create(:cash_transaction, user:, context:, user_bank_account: account, description: "Referenced return", reference_transactable: source)
    end
    operation = audited_operation { referenced.update!(description: "Temporary referenced return") }

    preview, result = apply(operation)

    expect(preview).to have_attributes(state: "previewable")
    expect(preview.rows.flat_map(&:support_issues)).to be_empty
    expect(result).to have_attributes(status: "applied")
    expect(referenced.reload).to have_attributes(description: "Referenced return", reference_transactable_id: source.id)
  end

  it "recreates an auto-applied transaction without a reference whose source was deleted" do
    source = PaperTrail.request(enabled: false) { create(:cash_transaction, user:, context:, user_bank_account: account, description: "Deleted sender source") }
    referenced = PaperTrail.request(enabled: false) do
      create(:cash_transaction, user:, context:, user_bank_account: account, description: "Recipient return", reference_transactable: source)
    end
    PaperTrail.request(enabled: false) { source.destroy! }
    operation = audited_operation(source: :actionable_message) { referenced.destroy! }

    preview, result = apply(operation)

    expect(preview).to have_attributes(state: "previewable")
    expect(preview.rows.flat_map(&:support_issues)).to be_empty
    expect(result).to have_attributes(status: "applied")
    expect(referenced.reload).to have_attributes(
      description: "Recipient return",
      reference_transactable_id: nil,
      reference_transactable_type: nil
    )
  end

  it "restores a card advance with its linked cash transaction" do
    user_card = PaperTrail.request(enabled: false) { create(:user_card, :random, user:) }
    card_transaction = PaperTrail.request(enabled: false) do
      create(
        :card_transaction,
        user:,
        context:,
        user_card:,
        description: "Advance origin",
        date: Date.new(2027, 3, 25),
        price: -2_000,
        category_transactions: [
          build(:category_transaction, category: user.built_in_category("CARD ADVANCE"), transactable: nil)
        ]
      )
    end
    advance = PaperTrail.request(enabled: false) do
      CashTransaction.create!(card_transaction.send(:advance_cash_transaction_params))
    end
    PaperTrail.request(enabled: false) { card_transaction.update_column(:advance_cash_transaction_id, advance.id) }
    operation = audited_operation { Audit::BulkMutation.update_columns!(card_transaction, description: "Temporary advance") }

    preview, result = apply(operation)

    expect(preview).to have_attributes(state: "previewable")
    expect(preview.rows.flat_map(&:support_issues)).to be_empty
    expect(result).to have_attributes(status: "applied")
    expect(card_transaction.reload).to have_attributes(description: "Advance origin", advance_cash_transaction_id: advance.id)
    expect(advance.reload).to have_attributes(cash_transaction_type: "CardTransaction")
  end

  it "uncreates a card transaction and restores its existing card-payment projection" do
    user_card = PaperTrail.request(enabled: false) { create(:user_card, :random, user:) }
    transaction_date = Date.new(2027, 3, 25)
    baseline = PaperTrail.request(enabled: false) do
      create(:card_transaction, user:, context:, user_card:, date: transaction_date, price: -5_000)
    end
    projection = baseline.card_installments.sole.cash_transaction
    projection_before = projection.slice(:price, :comment)
    created_transaction = nil
    operation = audited_operation do
      created_transaction = create(:card_transaction, user:, context:, user_card:, date: transaction_date, price: -2_300)
    end

    preview, result = apply(operation)

    expect(preview).to have_attributes(state: "previewable")
    expect(preview.rows.flat_map(&:support_issues)).to be_empty
    expect(result).to have_attributes(status: "applied")
    expect(CardTransaction.exists?(created_transaction.id)).to be(false)
    expect(CardInstallment.where(card_transaction_id: created_transaction.id)).to be_empty
    expect(projection.reload).to have_attributes(projection_before)
  end

  it "keeps an unknown future generated transaction shape read-only" do
    transaction = PaperTrail.request(enabled: false) { create(:cash_transaction, user:, context:) }
    PaperTrail.request(enabled: false) { transaction.update_column(:cash_transaction_type, "FutureProjection") }
    operation = audited_operation { transaction.update!(description: "Unknown projection edit") }

    preview = Audit::Rollback::Preview.new(operation:, actor: admin)

    expect(preview).to have_attributes(state: "read_only")
    expect(preview.rows.sole.support_issues.map(&:code)).to include("unsupported_transaction_graph")
  end
end
