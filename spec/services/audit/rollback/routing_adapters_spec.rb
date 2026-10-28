# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Audit rollback routing adapters" do
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
      token: preview.apply_token
    ).call
    [ preview, result ]
  end

  it "restores ordinary UserCard and UserBankAccount updates" do
    user_card = PaperTrail.request(enabled: false) { create(:user_card, :random, user:) }
    account = PaperTrail.request(enabled: false) { create(:user_bank_account, :random, user:) }
    original_limit = user_card.credit_limit
    original_name = account.user_bank_account_name
    operation = audited_operation do
      user_card.update!(credit_limit: original_limit + 10_000)
      account.update!(user_bank_account_name: "Temporary routing name")
    end

    preview, result = apply(operation)

    expect(preview).to have_attributes(state: "previewable")
    expect(result).to have_attributes(status: "applied")
    expect(user_card.reload.credit_limit).to eq(original_limit)
    expect(account.reload.user_bank_account_name).to eq(original_name)
  end

  it "restores an unused card's kind and debit bank-account link" do
    user_card = PaperTrail.request(enabled: false) { create(:user_card, :random, user:, card_kind: "prepaid") }
    account = PaperTrail.request(enabled: false) { create(:user_bank_account, :random, user:) }
    operation = audited_operation { user_card.update!(card_kind: "debit", user_bank_account: account) }

    preview, result = apply(operation)

    expect(preview).to have_attributes(state: "previewable")
    expect(result).to have_attributes(status: "applied")
    expect(user_card.reload).to be_prepaid
    expect(user_card.user_bank_account_id).to be_nil
  end

  it "conflicts before removing a bank account referenced by a debit card" do
    account = nil
    operation = audited_operation { account = create(:user_bank_account, :random, user:) }
    PaperTrail.request(enabled: false) do
      create(:user_card, :random, user:, card_kind: "debit", user_bank_account: account)
    end

    preview = Audit::Rollback::Preview.new(operation:, actor: admin)

    expect(preview).to have_attributes(state: "conflicted")
    expect(preview.rows.find { |row| row.record_type == "UserBankAccount" }.conflicts.map(&:code)).to include("later_dependencies")
  end

  it "undoes a prepaid purchase without creating an invoice or billing reference" do
    user_card = PaperTrail.request(enabled: false) { create(:user_card, :random, user:, card_kind: "prepaid") }
    transaction = nil
    operation = audited_operation do
      transaction = CardTransaction.new(user:, context:, user_card:, description: "Planned VA lunch", date: Time.zone.tomorrow, price: -1000)
      transaction.card_installments.first.price = -1000
      transaction.save!
    end

    preview, result = apply(operation)

    expect(preview).to have_attributes(state: "previewable")
    expect(result).to have_attributes(status: "applied")
    expect(CardTransaction).not_to exist(transaction.id)
    expect(Reference.where(user_card:)).not_to exist
    expect(CashTransaction.where(user_card:, cash_transaction_type: "CardInstallment")).not_to exist
  end

  it "recreates a destroyed UserCard before its billing references" do
    user_card = PaperTrail.request(enabled: false) { create(:user_card, :random, user:) }
    reference = PaperTrail.request(enabled: false) { create(:reference, user_card:, context:) }
    ids = [ user_card.id, reference.id ]
    operation = audited_operation { user_card.destroy! }

    preview, result = apply(operation)

    expect(operation.audit_versions.pluck(:item_type)).to contain_exactly("Reference", "UserCard")
    expect(preview).to have_attributes(state: "previewable")
    expect(result).to have_attributes(status: "applied")
    expect(UserCard).to exist(ids.first)
    expect(Reference).to exist(ids.last)
  end

  it "recreates a destroyed empty bank account with its original identity" do
    account = PaperTrail.request(enabled: false) { create(:user_bank_account, :random, user:) }
    account_id = account.id
    operation = audited_operation { account.destroy! }

    preview, result = apply(operation)

    expect(preview).to have_attributes(state: "previewable")
    expect(result).to have_attributes(status: "applied")
    expect(UserBankAccount).to exist(account_id)
  end

  it "conflicts before destroying a routing parent with a later dependent transaction" do
    account = nil
    operation = audited_operation { account = create(:user_bank_account, :random, user:) }
    PaperTrail.request(enabled: false) do
      create(:cash_transaction, user:, context:, user_bank_account: account)
    end

    preview = Audit::Rollback::Preview.new(operation:, actor: admin)

    expect(preview).to have_attributes(state: "conflicted")
    expect(preview.rows.find { |row| row.record_type == "UserBankAccount" }.conflicts.map(&:code)).to include("later_dependencies")
  end
end
