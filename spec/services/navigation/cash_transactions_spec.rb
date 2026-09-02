# frozen_string_literal: true

require "rails_helper"

RSpec.describe Navigation::CashTransactions do
  let(:user) { create(:user, :random) }
  let(:context) { user.main_context }
  let(:bank_account) { create(:user_bank_account, :random, user:) }
  let(:category) { create(:category, :random, user:) }
  let(:entity) { create(:entity, :random, user:) }
  let(:subscription) { create(:subscription, user:, context:) }
  let(:cash_transaction) do
    create(
      :cash_transaction,
      user:,
      context:,
      user_bank_account: bank_account,
      categories: [ category ],
      entities: [ entity ]
    )
  end

  def build_state(raw)
    described_class.new(
      raw:,
      fallback: "/cash_transactions",
      current_user: user,
      current_context: context
    )
  end

  it "retains allowlisted cash index state owned by the current user and context" do
    installment = cash_transaction.cash_installments.first
    raw = "/cash_transactions?active_month_years=%5B202607%5D&cash_transaction[cash_installment_ids][]=#{installment.id}" \
          "&cash_transaction[category_id][]=#{category.id}&cash_transaction[entity_id][]=#{entity.id}" \
          "&cash_transaction[id][]=#{cash_transaction.id}&cash_transaction[subscription_id][]=#{subscription.id}" \
          "&cash_transaction[user_bank_account_id][]=#{bank_account.id}&attach_to_subscription_id=#{subscription.id}&sort=description&direction=asc"

    state = build_state(raw)

    expect(state).to be_accepted
    expect(state.destination).to include("/cash_transactions?")
    expect(state.destination).to include("active_month_years=%5B202607%5D")
    expect(state.destination).to include("sort=description")
    expect(state.destination).to include(installment.id.to_s, category.id.to_s, entity.id.to_s, cash_transaction.id.to_s, subscription.id.to_s, bank_account.id.to_s)
  end

  it "rejects a foreign attach-to-subscription destination" do
    foreign_user = create(:user, :random)
    foreign_subscription = create(:subscription, user: foreign_user, context: foreign_user.main_context)

    state = build_state("/cash_transactions?attach_to_subscription_id=#{foreign_subscription.id}")

    expect(state.destination).to eq("/cash_transactions")
    expect(state.rejected_reason).to eq(:foreign_identifier)
  end

  it "strips form data and unrelated query keys" do
    state = build_state("/cash_transactions?cash_transaction[description]=secret&price=999&search_term=rent")

    expect(state).to be_accepted
    expect(state.destination).to eq("/cash_transactions?search_term=rent")
  end

  it "rejects foreign transaction, subscription, account, category, entity, and installment identifiers" do
    foreign_user = create(:user, :random)
    foreign_bank_account = create(:user_bank_account, :random, user: foreign_user)
    foreign_category = create(:category, :random, user: foreign_user)
    foreign_entity = create(:entity, :random, user: foreign_user)
    foreign_transaction = create(
      :cash_transaction,
      user: foreign_user,
      context: foreign_user.main_context,
      user_bank_account: foreign_bank_account
    )
    foreign_subscription = create(:subscription, user: foreign_user, context: foreign_user.main_context)
    foreign_values = {
      cash_installment_ids: foreign_transaction.cash_installments.first.id,
      category_id: foreign_category.id,
      entity_id: foreign_entity.id,
      id: foreign_transaction.id,
      subscription_id: foreign_subscription.id,
      user_bank_account_id: foreign_bank_account.id
    }

    foreign_values.each do |key, value|
      state = build_state("/cash_transactions?cash_transaction[#{key}]=#{value}")

      expect(state.destination).to eq("/cash_transactions")
      expect(state.rejected_reason).to eq(:foreign_identifier)
    end
  end

  it "falls back for another route or an external destination" do
    [ "/budgets", "https://evil.example/cash_transactions" ].each do |raw|
      expect(build_state(raw).destination).to eq("/cash_transactions")
    end
  end
end
