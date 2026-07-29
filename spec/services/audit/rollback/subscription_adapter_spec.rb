# frozen_string_literal: true

require "rails_helper"

RSpec.describe Audit::Rollback::Adapters::Subscription do
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

  it "restores subscription metadata and its linked cash and card transactions atomically" do
    subscription = PaperTrail.request(enabled: false) { create(:subscription, user:, context:, description: "Original subscription", comment: "Original note") }
    account = PaperTrail.request(enabled: false) { create(:user_bank_account, :random, user:) }
    user_card = PaperTrail.request(enabled: false) { create(:user_card, :random, user:) }
    subscription_category = user.built_in_category("SUBSCRIPTION")
    cash_transaction = PaperTrail.request(enabled: false) do
      create(
        :cash_transaction,
        user:,
        context:,
        user_bank_account: account,
        subscription:,
        description: subscription.description,
        date: Date.new(2027, 1, 10),
        category_transactions: [ CategoryTransaction.new(category: subscription_category) ]
      )
    end
    card_transaction = PaperTrail.request(enabled: false) do
      create(
        :card_transaction,
        user:,
        context:,
        user_card:,
        subscription:,
        description: subscription.description,
        date: Date.new(2027, 2, 10),
        category_transactions: [ CategoryTransaction.new(category: subscription_category) ]
      )
    end
    subscription.refresh_price!
    expect(cash_transaction.reload.subscription_id).to eq(subscription.id)
    expect(card_transaction.reload.subscription_id).to eq(subscription.id)
    original_price = subscription.reload.price
    operation = audited_operation do
      subscription.update!(
        description: "Temporary subscription",
        comment: "Temporary note",
        cash_transactions_attributes: [ { id: cash_transaction.id, price: cash_transaction.price - 100 } ],
        card_transactions_attributes: [ { id: card_transaction.id, price: card_transaction.price - 100 } ]
      )
    end

    preview, result = apply(operation)
    expect(operation.audit_versions.pluck(:item_subtype)).to include("Subscription", "CashTransaction", "CardTransaction")
    expect(preview).to have_attributes(state: "previewable")
    expect(result).to have_attributes(status: "applied")
    expect(subscription.reload).to have_attributes(description: "Original subscription", comment: "Original note", price: original_price)
    expect(cash_transaction.reload.description).to eq("Original subscription")
    expect(card_transaction.reload.description).to eq("Original subscription")
  end

  it "recreates an empty destroyed subscription with its allocations" do
    subscription = PaperTrail.request(enabled: false) { create(:subscription, user:, context:) }
    category = PaperTrail.request(enabled: false) { create(:category, :random, user:) }
    entity = PaperTrail.request(enabled: false) { create(:entity, :random, user:) }
    PaperTrail.request(enabled: false) do
      subscription.categories << category
      subscription.entities << entity
    end
    subscription_id = subscription.id
    operation = audited_operation { subscription.destroy! }

    preview, result = apply(operation)
    expect(preview).to have_attributes(state: "previewable")
    expect(result).to have_attributes(status: "applied")
    expect(Subscription.find(subscription_id).category_ids).to eq([ category.id ])
    expect(Subscription.find(subscription_id).entity_ids).to eq([ entity.id ])
  end

  it "conflicts before destroying a subscription with a later linked transaction" do
    subscription = nil
    operation = audited_operation { subscription = create(:subscription, user:, context:) }
    PaperTrail.request(enabled: false) do
      create(:cash_transaction, user:, context:, subscription:)
    end

    preview = Audit::Rollback::Preview.new(operation:, actor: admin)

    expect(preview).to have_attributes(state: "conflicted")
    expect(preview.rows.sole.conflicts.map(&:code)).to include("later_dependencies")
  end
end
