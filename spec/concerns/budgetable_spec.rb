# frozen_string_literal: true

require "rails_helper"

RSpec.describe Budgetable, type: :concern do
  let(:user) { create(:user, :random) }
  let(:user_card) { create(:user_card, :random, user:) }
  let(:category) { create(:category, :random, user:) }
  let(:entity) { create(:entity, :random, user:) }

  let(:applicable_transaction) do
    build(:cash_transaction, :random,
          user:, price: -200_00,
          cash_installments: build_list(:cash_installment, 2, price: -100_00) { |ci, i| ci.number = i + 1 },
          category_transactions: [ build(:category_transaction, :random, category:, transactable: nil) ],
          entity_transactions: [ build(:entity_transaction, :random, entity: entity, price: 0, is_payer: false, transactable: nil) ])
  end

  let(:non_applicable_transaction) do
    build(:cash_transaction, :random,
          user:, price: -200_00,
          cash_installments: build_list(:cash_installment, 2, price: -100_00) { |ci, i| ci.number = i + 1 },
          category_transactions: [ build(:category_transaction, :random, category: create(:category, :random), transactable: nil) ])
  end

  let(:budget) do
    build(:budget, value: -1_000_00, month: applicable_transaction.month, year: applicable_transaction.year, inclusive: false, user:,
                   budget_categories: [ BudgetCategory.new(category:) ],
                   budget_entities: [ BudgetEntity.new(entity:) ])
  end

  let(:applicable_card_transaction) do
    build(:card_transaction, :random,
          user:, price: -200_00,
          card_installments: build_list(:card_installment, 2, price: -100_00) { |ci, i| ci.number = i + 1 },
          category_transactions: [ build(:category_transaction, :random, category:, transactable: nil) ],
          entity_transactions: [ build(:entity_transaction, :random, entity: entity, price: 0, is_payer: false, transactable: nil) ])
  end

  let(:non_applicable_card_transaction) do
    build(:card_transaction, :random,
          user:, price: -200_00,
          card_installments: build_list(:card_installment, 2, price: -100_00) { |ci, i| ci.number = i + 1 },
          category_transactions: [ build(:category_transaction, :random, category: create(:category, :random), transactable: nil) ])
  end

  def validate_budget(installments, more_installments = nil)
    installments_total = installments.where(month: budget.month, year: budget.year).sum(:price)
    installments_total += more_installments.where(month: budget.month, year: budget.year).sum(:price) if more_installments
    expect(budget.remaining_value).to eq(budget.value - installments_total)
  end

  describe "[ concern behaviour ]" do
    context "( creates budget and then creates transactions )" do
      before { budget.save }

      it "creates a transaction that applies to the budget" do
        applicable_transaction.save
        budget.reload

        validate_budget(applicable_transaction.cash_installments)
      end

      it "creates a transaction that does not apply to the budget" do
        non_applicable_transaction.save
        budget.reload

        expect(budget.remaining_value).to eq(budget.value)
      end
    end

    context "( creates transaction that does not apply and then creates budget )" do
      before do
        non_applicable_transaction.save
        budget.save
      end

      it "does not update the budget" do
        budget.reload
        expect(budget.remaining_value).to eq(budget.value)
      end

      it "creates transactions that apply to the budget" do
        applicable_transaction.save
        budget.reload

        validate_budget(applicable_transaction.cash_installments)
      end
    end

    context "( creates transaction that applies and then creates budget )" do
      before do
        applicable_transaction.save
        budget.save
      end

      it "updates the budget accordingly" do
        validate_budget(applicable_transaction.cash_installments)
      end

      it "creates another transaction that applies to the budget and update remaining value" do
        applicable_card_transaction.save
        budget.reload

        validate_budget(applicable_card_transaction.card_installments, applicable_transaction.cash_installments)
      end

      it "updates the transactions to apply to the budget" do
        applicable_transaction.price = -333_00
        applicable_transaction.cash_installments = build_list(:cash_installment, 3, price: -111_00) { |ci, i| ci.number = i + 1 }
        applicable_transaction.save

        budget.reload

        validate_budget(applicable_transaction.cash_installments)
      end

      it "updates the transactions to no longer apply to the budget" do
        applicable_transaction.categories = build_list(:category, 1, :random, category_name: "Budget Category", user:)
        applicable_transaction.entities = build_list(:entity, 1, :random, user:)
        applicable_transaction.save

        budget.reload

        expect(budget.remaining_value).to eq(budget.value)
      end

      it "updates the non-inclusive budget to no longer be applied to the transaction" do
        budget.categories = [ create(:category, :random, user:) ]
        budget.entities = [ create(:entity, :random, user:) ]
        budget.save

        expect(budget.remaining_value).to eq(budget.value)
      end

      it "updates the budget to inclusive and still be applied to the transaction" do
        budget.inclusive = true
        budget.save

        validate_budget(applicable_transaction.cash_installments)
      end

      it "updates the inclusive budget to no longer be applied to the transaction" do
        budget.inclusive = true
        budget.entities = [ create(:entity, :random, user:) ]
        budget.save

        expect(budget.remaining_value).to eq(budget.value)
      end

      it "destroys the transactions that apply to the budget" do
        applicable_transaction.destroy

        budget.reload

        expect(budget.remaining_value).to eq(budget.value)
      end
    end
  end
end
