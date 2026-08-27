# frozen_string_literal: true

require "rails_helper"

RSpec.describe Navigation::CardTransactions do
  let(:user) { create(:user, :random) }
  let(:context) { user.main_context }
  let(:user_card) { create(:user_card, :random, user:) }
  let(:category) { create(:category, :random, user:) }
  let(:entity) { create(:entity, :random, user:) }
  let(:subscription) { create(:subscription, user:, context:) }
  let(:card_transaction) do
    create(
      :card_transaction,
      user:,
      context:,
      user_card:,
      categories: [ category ],
      entities: [ entity ]
    )
  end

  def build_state(raw)
    described_class.new(
      raw:,
      fallback: "/card_transactions",
      current_user: user,
      current_context: context
    )
  end

  it "retains allowlisted card and invoice state owned by the current user and context" do
    installment = card_transaction.card_installments.first
    raw = "/card_transactions?active_month_years=%5B202607%5D&default_year=2026&user_card_id=#{user_card.id}" \
          "&card_transaction[card_installment_ids][]=#{installment.id}&card_transaction[category_id][]=#{category.id}" \
          "&card_transaction[entity_id][]=#{entity.id}&card_transaction[id][]=#{card_transaction.id}" \
          "&card_transaction[subscription_id][]=#{subscription.id}&sort=description&direction=desc"

    state = build_state(raw)

    expect(state).to be_accepted
    expect(state.destination).to include("/card_transactions?")
    expect(state.destination).to include("active_month_years=%5B202607%5D", "default_year=2026", "sort=description")
    expect(state.destination).to include(installment.id.to_s, category.id.to_s, entity.id.to_s, card_transaction.id.to_s, subscription.id.to_s, user_card.id.to_s)
  end

  it "accepts the canonical search route and strips unrelated form data" do
    state = build_state("/card_transactions/search?card_transaction[description]=secret&price=999&search_term=rent")

    expect(state).to be_accepted
    expect(state.destination).to eq("/card_transactions/search?search_term=rent")
  end

  it "rejects foreign transaction, subscription, card, category, entity, and installment identifiers" do
    foreign_user = create(:user, :random)
    foreign_card = create(:user_card, :random, user: foreign_user)
    foreign_category = create(:category, :random, user: foreign_user)
    foreign_entity = create(:entity, :random, user: foreign_user)
    foreign_transaction = create(:card_transaction, user: foreign_user, context: foreign_user.main_context, user_card: foreign_card)
    foreign_subscription = create(:subscription, user: foreign_user, context: foreign_user.main_context)
    foreign_values = {
      card_installment_ids: foreign_transaction.card_installments.first.id,
      category_id: foreign_category.id,
      entity_id: foreign_entity.id,
      id: foreign_transaction.id,
      subscription_id: foreign_subscription.id,
      user_card_id: foreign_card.id
    }

    foreign_values.each do |key, value|
      raw =
        if key == :user_card_id
          "/card_transactions?user_card_id=#{value}"
        else
          "/card_transactions?card_transaction[#{key}]=#{value}"
        end
      state = build_state(raw)

      expect(state.destination).to eq("/card_transactions")
      expect(state.rejected_reason).to eq(:foreign_identifier)
    end
  end

  it "falls back for another route or an external destination" do
    [ "/budgets", "https://evil.example/card_transactions" ].each do |raw|
      expect(build_state(raw).destination).to eq("/card_transactions")
    end
  end
end
