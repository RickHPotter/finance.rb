# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Investments", type: :request do
  let(:user) { create(:user, :random) }
  let(:bank) { create(:bank, :random) }
  let(:user_bank_account) { create(:user_bank_account, :random, user:, bank:) }
  let(:investment_type) { create(:investment_type, :random) }

  before { sign_in user }

  def switch_to_context!(context)
    patch switch_context_path(context)
    expect(response).to redirect_to(root_path)
  end

  describe "[ #index ]" do
    it "renders successfully" do
      get investments_path

      expect(response).to have_http_status(:success)
    end
  end

  describe "[ #create ]" do
    it "creates an investment" do
      expect do
        post investments_path, params: {
          investment: {
            description: "Tesouro Selic",
            price: 1234,
            date: Date.new(2026, 3, 14),
            month: 3,
            year: 2026,
            user_id: user.id,
            user_bank_account_id: user_bank_account.id,
            investment_type_id: investment_type.id
          }
        }, headers: turbo_stream_headers
      end.to change(Investment, :count).by(1)
    end
  end

  describe "[ #update ]" do
    it "updates the record" do
      investment = create(:investment, user:, user_bank_account:, investment_type:)

      patch investment_path(investment), params: {
        investment: {
          description: "Updated Investment",
          price: investment.price,
          date: investment.date,
          month: investment.month,
          year: investment.year,
          user_id: user.id,
          user_bank_account_id: user_bank_account.id,
          investment_type_id: investment_type.id
        }
      }, headers: turbo_stream_headers

      expect(investment.reload.description).to eq("Updated Investment")
    end
  end

  describe "[ #destroy ]" do
    it "destroys the record" do
      investment = create(:investment, user:, user_bank_account:, investment_type:)

      expect do
        delete investment_path(investment), headers: turbo_stream_headers
      end.to change(Investment, :count).by(-1)
    end
  end

  describe "[ #month_year ]" do
    it "renders successfully" do
      create(:investment, user:, user_bank_account:, investment_type:, month: 3, year: 2026, date: Date.new(2026, 3, 14))

      get month_year_investments_path, params: { month_year: "202603" }

      expect(response).to have_http_status(:success)
    end
  end

  describe "[ context isolation ]" do
    it "keeps create, update, and destroy changes inside the derived context" do
      main_investment = create(
        :investment,
        user:,
        context: user.main_context,
        user_bank_account:,
        investment_type:,
        description: "Main isolated investment",
        price: 1234,
        date: Date.new(2026, 3, 14)
      )

      derived_context = Logic::ContextCloneService.new(
        source_context: user.main_context,
        name: "Investment Isolation"
      ).call
      derived_investment = derived_context.investments.find_by!(description: main_investment.description)

      switch_to_context!(derived_context)

      expect do
        post investments_path, params: {
          investment: {
            description: "Derived only investment",
            price: 5678,
            date: Date.new(2026, 4, 14),
            month: 4,
            year: 2026,
            user_id: user.id,
            user_bank_account_id: user_bank_account.id,
            investment_type_id: investment_type.id
          }
        }, headers: turbo_stream_headers
      end.to change { derived_context.investments.reload.count }.by(1)

      expect(user.main_context.investments.reload.count).to eq(1)

      patch investment_path(derived_investment), params: {
        investment: {
          description: "Derived updated investment",
          price: derived_investment.price,
          date: derived_investment.date,
          month: derived_investment.month,
          year: derived_investment.year,
          user_id: user.id,
          user_bank_account_id: user_bank_account.id,
          investment_type_id: investment_type.id
        }
      }, headers: turbo_stream_headers

      expect(derived_investment.reload.description).to eq("Derived updated investment")
      expect(main_investment.reload.description).to eq("Main isolated investment")

      expect do
        delete investment_path(derived_investment), headers: turbo_stream_headers
      end.to change { derived_context.investments.reload.count }.by(-1)

      expect(user.main_context.investments.reload.count).to eq(1)

      expect(Investment.exists?(main_investment.id)).to be(true)
    end
  end

  describe "[ cross-context access denial ]" do
    it "does not allow editing, updating, or destroying a main-context investment while in a derived context" do
      main_investment = create(
        :investment,
        user:,
        context: user.main_context,
        user_bank_account:,
        investment_type:,
        description: "Main inaccessible investment"
      )

      derived_context = Logic::ContextCloneService.new(
        source_context: user.main_context,
        name: "Investment Access Isolation"
      ).call

      switch_to_context!(derived_context)

      get edit_investment_path(main_investment)
      expect(response).to have_http_status(:not_found)

      patch investment_path(main_investment), params: {
        investment: {
          description: "Should not update",
          price: main_investment.price,
          date: main_investment.date,
          month: main_investment.month,
          year: main_investment.year,
          user_id: user.id,
          user_bank_account_id: user_bank_account.id,
          investment_type_id: investment_type.id
        }
      }, headers: turbo_stream_headers
      expect(response).to have_http_status(:not_found)

      delete investment_path(main_investment), headers: turbo_stream_headers
      expect(response).to have_http_status(:not_found)
    end
  end
end
