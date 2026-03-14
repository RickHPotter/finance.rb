# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Investments", type: :request do
  let(:user) { create(:user, :random) }
  let(:bank) { create(:bank, :random) }
  let(:user_bank_account) { create(:user_bank_account, :random, user:, bank:) }
  let(:investment_type) { create(:investment_type, :random) }

  before { sign_in user }

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
end
