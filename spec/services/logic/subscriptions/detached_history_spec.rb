# frozen_string_literal: true

require "rails_helper"

RSpec.describe Logic::Subscriptions::DetachedHistory do
  let(:user) { create(:user, :random) }
  let(:context) { user.main_context }
  let(:subscription) { create(:subscription, user:, context:) }
  let(:bank_account) { create(:user_bank_account, :random, user:) }
  let(:user_card) { create(:user_card, :random, user:) }

  def create_version(item_type:, item_id:, object:, object_changes:, context_id: context.id, created_at: Time.current, event: :update)
    operation = AuditOperation.create!(source: :web, result: :committed, actor_id: user.id, context_id:)
    AuditVersion.create!(
      operation:,
      owner_id: user.id,
      context_id:,
      item_type:,
      item_subtype: item_type,
      item_id:,
      event:,
      mutation_source: :web,
      object:,
      object_changes:,
      metadata: {},
      created_at:
    )
  end

  def detached_version(record, created_at: Time.current)
    create_version(
      item_type: record.class.name,
      item_id: record.id,
      object: record.attributes.merge("subscription_id" => subscription.id),
      object_changes: { "subscription_id" => [ subscription.id, nil ] },
      created_at:
    )
  end

  it "returns only context-owned audited detached identities and deduplicates repeated history" do
    detached_cash = create(
      :cash_transaction,
      user:,
      context:,
      user_bank_account: bank_account,
      description: "Audited detached cash",
      date: Time.zone.local(2026, 6, 1),
      subscription: nil
    )
    other_subscription = create(:subscription, user:, context:)
    detached_card = create(
      :card_transaction,
      user:,
      context:,
      user_card:,
      subscription: other_subscription,
      description: "Audited detached card",
      date: Time.zone.local(2026, 8, 1)
    )
    reattached = create(:cash_transaction, user:, context:, user_bank_account: bank_account, subscription:, description: "Reattached cash")
    lookalike = create(:cash_transaction, user:, context:, user_bank_account: bank_account, description: detached_cash.description)
    foreign_context = create(:context, user:)
    foreign_history = create(:card_transaction, user:, context:, user_card:, description: "Foreign audit evidence")
    destroyed_item_id = CashTransaction.maximum(:id).to_i + 10_000

    detached_version(detached_cash, created_at: 3.days.ago)
    detached_version(detached_cash, created_at: 2.days.ago)
    detached_version(detached_card, created_at: 1.day.ago)
    detached_version(reattached)
    create_version(
      item_type: "CardTransaction",
      item_id: foreign_history.id,
      object: foreign_history.attributes.merge("subscription_id" => subscription.id),
      object_changes: { "subscription_id" => [ subscription.id, nil ] },
      context_id: foreign_context.id
    )
    create_version(
      item_type: "CashTransaction",
      item_id: destroyed_item_id,
      object: {
        "id" => destroyed_item_id,
        "description" => "Destroyed detached cash",
        "date" => Time.zone.local(2026, 7, 1).iso8601,
        "price" => -7_500,
        "subscription_id" => subscription.id
      },
      object_changes: { "subscription_id" => [ subscription.id, nil ] },
      event: :destroy
    )

    audit_count = AuditVersion.count
    cash_updated_at = detached_cash.updated_at
    card_updated_at = detached_card.updated_at
    entries = described_class.call(subscription:)

    expect(entries.map { |entry| [ entry.record_type, entry.item_id ] }).to eq(
      [ [ "CardTransaction", detached_card.id ], [ "CashTransaction", destroyed_item_id ], [ "CashTransaction", detached_cash.id ] ]
    )
    entry_keys = entries.map { |entry| [ entry.record_type, entry.item_id ] }
    expect(entry_keys.count([ "CashTransaction", detached_cash.id ])).to eq(1)
    expect(entry_keys).not_to include(
      [ "CashTransaction", reattached.id ],
      [ "CashTransaction", lookalike.id ],
      [ "CardTransaction", foreign_history.id ]
    )
    expect(entries.find { |entry| entry.record_type == "CashTransaction" && entry.item_id == detached_cash.id }).to be_live
    expect(entries.find { |entry| entry.record_type == "CashTransaction" && entry.item_id == destroyed_item_id }).to have_attributes(
      destroyed?: true,
      description: "Destroyed detached cash",
      price: -7_500
    )
    expect(AuditVersion.count).to eq(audit_count)
    expect(detached_cash.reload.updated_at).to eq(cash_updated_at)
    expect(detached_card.reload.updated_at).to eq(card_updated_at)
  end

  it "caps identities by the newest audit evidence with a deterministic policy" do
    stub_const("#{described_class}::LIMIT", 2)

    [ 1, 2, 3 ].each do |item_id|
      create_version(
        item_type: "CashTransaction",
        item_id: item_id + 10_000,
        object: {
          "description" => "Historical #{item_id}",
          "date" => Time.zone.local(2026, item_id, 1).iso8601,
          "subscription_id" => subscription.id
        },
        object_changes: { "subscription_id" => [ subscription.id, nil ] },
        created_at: item_id.days.ago,
        event: :destroy
      )
    end

    entries = described_class.call(subscription:)

    expect(entries.size).to eq(2)
    expect(entries.map(&:description)).to contain_exactly("Historical 1", "Historical 2")
  end

  it "excludes reattached identities before applying the cap" do
    stub_const("#{described_class}::LIMIT", 1)
    reattached = create(:cash_transaction, user:, context:, user_bank_account: bank_account, subscription:, description: "Recent reattachment")
    detached_version(reattached, created_at: Time.current)
    destroyed_item_id = CashTransaction.maximum(:id).to_i + 10_000
    create_version(
      item_type: "CashTransaction",
      item_id: destroyed_item_id,
      object: {
        "description" => "Older actual detachment",
        "date" => 1.month.ago.iso8601,
        "subscription_id" => subscription.id
      },
      object_changes: { "subscription_id" => [ subscription.id, nil ] },
      created_at: 1.day.ago,
      event: :destroy
    )

    entries = described_class.call(subscription:)

    expect(entries.map(&:description)).to eq([ "Older actual detachment" ])
  end
end
