# frozen_string_literal: true

require "rails_helper"

RSpec.describe IndexState::CardTransactions do
  include ActiveSupport::Testing::TimeHelpers

  it "activates only months containing explicitly selected installments" do
    user = create(:user, :random)
    card = create(:user_card, :random, user:)
    selected = create(:card_transaction, user:, context: user.main_context, user_card: card, date: Date.new(2026, 4, 10), month: 4, year: 2026)
    create(:card_transaction, user:, context: user.main_context, user_card: card, date: Date.new(2026, 5, 10), month: 5, year: 2026)

    state = described_class.new(
      current_user: user,
      current_context: user.main_context,
      params: ActionController::Parameters.new(all_month_years: true),
      card_installments: user.main_context.card_installments,
      transaction_filters: { card_installment_ids: selected.card_installments.ids }
    ).to_h

    expect(state[:active_month_years]).to eq([ 202_604 ])
    expect(state[:count_by_month_year].transform_values(&:count)).to eq(202_604 => 1)
  end

  it "defaults to a still-unpaid target invoice whose closing date was shifted by a reference merge" do
    travel_to(Time.zone.local(2026, 9, 12, 12)) do
      user = create(:user, :random)
      user_card = create(:user_card, :random, user:, due_date_day: 13, days_until_due_date: 7)
      context = user.main_context
      create_reference(user_card:, context:, month: 10, reference_date: Date.new(2026, 10, 13), closing_date: Date.new(2026, 9, 6))
      create_reference(user_card:, context:, month: 11, reference_date: Date.new(2026, 11, 13), closing_date: Date.new(2026, 11, 6))
      create_card_transaction(user:, user_card:, context:, month: 10, paid: false)
      create_card_transaction(user:, user_card:, context:, month: 11, paid: false)

      expect(index_state(user:, user_card:, context:)[:active_month_years]).to eq([ 202_610 ])
    end
  end

  it "uses the next open reference when a shifted target invoice is already paid" do
    travel_to(Time.zone.local(2026, 9, 12, 12)) do
      user = create(:user, :random)
      user_card = create(:user_card, :random, user:, due_date_day: 13, days_until_due_date: 7)
      context = user.main_context
      create_reference(user_card:, context:, month: 10, reference_date: Date.new(2026, 10, 13), closing_date: Date.new(2026, 9, 6))
      create_reference(user_card:, context:, month: 11, reference_date: Date.new(2026, 11, 13), closing_date: Date.new(2026, 11, 6))
      create_card_transaction(user:, user_card:, context:, month: 10, paid: true)
      create_card_transaction(user:, user_card:, context:, month: 11, paid: false)

      expect(index_state(user:, user_card:, context:)[:active_month_years]).to eq([ 202_611 ])
    end
  end

  private

  def create_reference(user_card:, context:, month:, reference_date:, closing_date:)
    create(
      :reference,
      user_card:,
      context:,
      month:,
      year: 2026,
      reference_date:,
      reference_closing_date: closing_date,
      skip_reference_closing_date_calculation: true
    )
  end

  def create_card_transaction(user:, user_card:, context:, month:, paid:)
    create(
      :card_transaction,
      user:,
      user_card:,
      context:,
      date: Time.zone.local(2026, month - 1, 5, 12),
      month:,
      year: 2026,
      price: -1_000,
      card_installments: [
        build(:card_installment, number: 1, date: Time.zone.local(2026, month - 1, 5, 12), month:, year: 2026, price: -1_000, paid:)
      ]
    )
  end

  def index_state(user:, user_card:, context:)
    installments = context.card_installments.joins(:card_transaction).where(card_transactions: { user_card_id: user_card.id })
    described_class.new(
      current_user: user,
      current_context: context,
      params: ActionController::Parameters.new,
      card_installments: installments,
      user_card:
    ).to_h
  end
end
