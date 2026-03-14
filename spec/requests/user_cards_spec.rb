# frozen_string_literal: true

require "rails_helper"

RSpec.describe "UserCards", type: :request do
  let(:user) { create(:user, :random) }
  let(:bank) { create(:bank, :random) }
  let(:card) { create(:card, :random, bank:) }

  before { sign_in user }

  describe "[ #index ]" do
    it "renders successfully" do
      get user_cards_path

      expect(response).to have_http_status(:success)
    end
  end

  describe "[ #create ]" do
    it "creates a user card" do
      expect do
        post user_cards_path, params: {
          user_card: {
            user_card_name: "Gaara",
            due_date_day: 10,
            days_until_due_date: 7,
            min_spend: 10_000,
            credit_limit: 200_000,
            active: true,
            card_id: card.id,
            user_id: user.id
          }
        }, headers: turbo_stream_headers
      end.to change(UserCard, :count).by(1)
    end
  end

  describe "[ #update ]" do
    it "updates the record" do
      user_card = create(:user_card, user:, card:)

      patch user_card_path(user_card), params: {
        user_card: {
          user_card_name: "Sasuke",
          due_date_day: user_card.due_date_day,
          days_until_due_date: user_card.days_until_due_date,
          min_spend: user_card.min_spend,
          credit_limit: user_card.credit_limit,
          active: user_card.active,
          card_id: card.id,
          user_id: user.id
        }
      }, headers: turbo_stream_headers

      expect(user_card.reload.user_card_name).to eq("Sasuke")
    end
  end

  describe "[ #destroy ]" do
    it "destroys a card without transactions" do
      user_card = create(:user_card, user:, card:)

      expect do
        delete user_card_path(user_card), headers: turbo_stream_headers
      end.to change(UserCard, :count).by(-1)
    end
  end

  describe "[ #reference_date ]" do
    it "returns the reference date as json" do
      user_card = create(:user_card, user:, card:)

      get reference_date_user_card_path(user_card), params: { year: 2026, month: 3 }

      expect(response).to have_http_status(:success)
      expect(JSON.parse(response.body)).to include("reference_date")
    end
  end
end
