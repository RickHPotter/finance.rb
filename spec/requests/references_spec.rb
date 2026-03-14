# frozen_string_literal: true

require "rails_helper"

RSpec.describe "References", type: :request do
  let(:user) { create(:user, :random) }
  let(:bank) { create(:bank, :random) }
  let(:card) { create(:card, :random, bank:) }
  let(:user_card) { create(:user_card, :random, user:, card:) }
  let(:reference) { create(:reference, user_card:) }

  before { sign_in user }

  describe "[ #index ]" do
    it "returns the card references as json" do
      reference

      get user_card_references_path(user_card)

      expect(response).to have_http_status(:success)
      expect(JSON.parse(response.body).pluck("id")).to include(reference.id)
    end
  end

  describe "[ #edit ]" do
    it "renders successfully" do
      get edit_user_card_reference_path(user_card, reference)

      expect(response).to have_http_status(:success)
    end
  end

  describe "[ #update ]" do
    it "updates the reference and redirects to the user card edit page" do
      patch user_card_reference_path(user_card, reference), params: {
        reference: {
          reference_closing_date: Date.new(2026, 3, 7),
          reference_date: Date.new(2026, 3, 15)
        }
      }

      expect(reference.reload.reference_closing_date).to eq(Date.new(2026, 3, 7))
      expect(reference.reference_date).to eq(Date.new(2026, 3, 15))
      expect(response).to redirect_to(edit_user_card_path(user_card))
    end
  end

  describe "[ #merge ]" do
    it "renders successfully" do
      get merge_user_card_references_path(user_card, id: reference.id)

      expect(response).to have_http_status(:success)
    end
  end
end
