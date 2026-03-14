# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Budgets", type: :request do
  let(:user) { create(:user, :random) }
  let(:category) { create(:category, :random, user:) }

  before { sign_in user }

  describe "[ #index ]" do
    it "renders successfully" do
      get budgets_path

      expect(response).to have_http_status(:success)
    end
  end

  describe "[ #create ]" do
    it "creates a budget" do
      expect do
        post budgets_path, params: {
          budget: {
            description: "Food Budget",
            value: -10_000,
            inclusive: false,
            first_installment_only: false,
            month_year: "2026-03",
            active: true,
            user_id: user.id,
            budget_categories_attributes: [ { category_id: category.id } ],
            budget_entities_attributes: []
          }
        }, headers: turbo_stream_headers
      end.to change(Budget, :count).by(1)
    end
  end

  describe "[ #update ]" do
    it "updates the record" do
      budget = create(:budget, user:, budget_categories: [ build(:budget_category, category:) ])

      patch budget_path(budget), params: {
        budget: {
          description: "Updated Budget",
          value: budget.value,
          inclusive: budget.inclusive,
          first_installment_only: budget.first_installment_only,
          month: budget.month,
          year: budget.year,
          active: budget.active,
          user_id: user.id,
          budget_categories_attributes: budget.budget_categories.map { |bc| { id: bc.id, category_id: bc.category_id } },
          budget_entities_attributes: []
        }
      }, headers: turbo_stream_headers

      expect(budget.reload.description).to eq("Updated Budget")
    end
  end

  describe "[ #destroy ]" do
    it "destroys the record" do
      budget = create(:budget, user:, budget_categories: [ build(:budget_category, category:) ])

      expect do
        delete budget_path(budget), headers: turbo_stream_headers
      end.to change(Budget, :count).by(-1)
    end
  end

  describe "[ #month_year ]" do
    it "renders successfully" do
      create(:budget, user:, month: 3, year: 2026, budget_categories: [ build(:budget_category, category:) ])

      get month_year_budgets_path, params: { month_year: "202603" }

      expect(response).to have_http_status(:success)
    end
  end
end
