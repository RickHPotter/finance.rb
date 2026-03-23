# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Budget context isolation" do
  it "updates only the derived context remaining value when a matching transaction is created there" do
    user = create(:user, :random)
    category = create(:category, :random, user:)
    entity = create(:entity, :random, user:)
    bank = create(:bank, :random)
    user_bank_account = create(:user_bank_account, :random, user:, bank:)

    main_budget = create(
      :budget,
      user:,
      context: user.main_context,
      value: -1_000_00,
      month: 3,
      year: 2026,
      inclusive: false,
      budget_categories: [ build(:budget_category, category:) ],
      budget_entities: [ build(:budget_entity, entity:) ]
    )

    derived_context = Logic::ContextCloneService.new(
      source_context: user.main_context,
      name: "Budget Remaining Isolation"
    ).call
    derived_budget = derived_context.budgets.find_by!(description: main_budget.description, month: 3, year: 2026)
    main_remaining_before = main_budget.reload.remaining_value

    create(
      :cash_transaction,
      user:,
      context: derived_context,
      user_bank_account:,
      price: -200_00,
      date: Date.new(2026, 3, 10),
      month: 3,
      year: 2026,
      cash_installments: [
        build(:cash_installment, number: 1, date: Date.new(2026, 3, 10), month: 3, year: 2026, price: -100_00),
        build(:cash_installment, number: 2, date: Date.new(2026, 3, 20), month: 3, year: 2026, price: -100_00)
      ],
      category_transactions: [ build(:category_transaction, :random, category:, transactable: nil) ],
      entity_transactions: [ build(:entity_transaction, :random, entity:, price: 0, is_payer: false, transactable: nil) ]
    )

    expect(derived_budget.reload.remaining_value).not_to eq(main_remaining_before)
    expect(main_budget.reload.remaining_value).to eq(main_remaining_before)
  end
end
