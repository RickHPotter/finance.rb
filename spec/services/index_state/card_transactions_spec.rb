# frozen_string_literal: true

require "rails_helper"

RSpec.describe IndexState::CardTransactions do
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
end
