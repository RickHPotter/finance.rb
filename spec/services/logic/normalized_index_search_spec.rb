# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Normalized financial index search" do
  let(:user) { create(:user, :random) }
  let(:context) { user.main_context }
  let(:bank) { create(:bank, :random) }
  let(:card) { create(:card, :random, bank:) }
  let(:user_bank_account) { create(:user_bank_account, :random, user:, bank:) }
  let(:user_card) { create(:user_card, :random, user:, card:) }
  let(:date) { Time.zone.local(2026, 9, 9, 12) }
  let(:month_year) { "202609" }
  let(:search_term) { "  refeicao classica " }

  it "normalizes cash transaction rows and month counts" do
    transaction = create(:cash_transaction, user:, context:, user_bank_account:, description: "REFEIÇÃO   CLÁSSICA", date:, month: 9, year: 2026)
    installment = transaction.cash_installments.first
    installment.update!(date:, month: 9, year: 2026)

    rows = Logic::CashInstallments.find_by_ref_month_year(context, 9, 2026, search_term:, associations: {})
    counts = Logic::CashTransactions.find_count_based_on_search(context, {}, { search_term: })

    expect(rows).to contain_exactly(installment)
    expect(counts.fetch(202_609)).to contain_exactly(installment)
  end

  it "normalizes the entity-scoped cash installment query" do
    entity = create(:entity, :random, user:)
    transaction = create(:cash_transaction, user:, context:, user_bank_account:, description: "REFEIÇÃO   CLÁSSICA", date:, month: 9, year: 2026)
    transaction.entity_transactions.destroy_all
    create(:entity_transaction, entity:, transactable: transaction)

    rows = Logic::CashInstallments.find_by_query(context, entity.id, search_term)

    expect(rows).to contain_exactly(transaction.cash_installments.first)
  end

  it "normalizes card transaction rows and month counts" do
    transaction = create(:card_transaction, user:, context:, user_card:, description: "REFEIÇÃO   CLÁSSICA", date:, month: 9, year: 2026)
    installment = transaction.card_installments.first
    installment.update!(date:, month: 9, year: 2026)
    params = { month_year:, search_term: }

    rows = Logic::CardInstallments.find_ref_month_year_by_params(context, {}, params)
    counts = Logic::CardInstallments.find_count_based_on_search(context, {}, { search_term: })

    expect(rows).to contain_exactly(installment)
    expect(counts.fetch(202_609)).to contain_exactly(installment)
  end

  it "normalizes budget rows and month counts" do
    budget = create(:budget, user:, context:, description: "REFEIÇÃO   CLÁSSICA", month: 9, year: 2026)

    rows = Logic::Budgets.find_by_ref_month_year(context, 9, 2026, search_term:, associations: {})
    counts = Logic::Budgets.find_count_based_on_search(context, {}, { search_term: })

    expect(rows).to contain_exactly(budget)
    expect(counts.fetch(202_609)).to contain_exactly(budget)
  end

  it "normalizes investment rows and month counts" do
    investment = create(:investment, user:, context:, user_bank_account:, description: "REFEIÇÃO   CLÁSSICA", date:, month: 9, year: 2026)

    rows = Logic::Investments.find_ref_month_year_by_params(context, {}, { month_year:, search_term: })
    counts = Logic::Investments.find_count_based_on_search(context, {}, { search_term: })

    expect(rows).to contain_exactly(investment)
    expect(counts.fetch(202_609)).to contain_exactly(investment)
  end
end
