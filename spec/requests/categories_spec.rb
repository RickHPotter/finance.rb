# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Categories", type: :request do
  let(:user) { create(:user, :random) }
  let(:bank) { create(:bank, :random) }
  let(:card) { create(:card, :random, bank:) }

  before do
    create(:user_card, :random, user:, card:)
    sign_in user
  end

  describe "[ #index ]" do
    it "renders successfully" do
      get categories_path

      expect(response).to have_http_status(:success)
    end
  end

  describe "[ #create ]" do
    it "creates a category" do
      expect do
        post categories_path, params: {
          category: {
            category_name: "Travel",
            colour: "#123456",
            active: true,
            user_id: user.id
          }
        }, headers: turbo_stream_headers
      end.to change(Category, :count).by(1)
    end
  end

  describe "[ #update ]" do
    it "updates the record" do
      category = create(:category, user:)

      patch category_path(category), params: {
        category: {
          category_name: "Updated Category",
          colour: category.colour,
          active: category.active,
          user_id: user.id
        }
      }, headers: turbo_stream_headers

      expect(category.reload.category_name).to eq("Updated Category")
    end
  end

  describe "[ #destroy ]" do
    it "destroys a category without transactions" do
      category = create(:category, user:)

      expect do
        delete category_path(category), headers: turbo_stream_headers
      end.to change(Category, :count).by(-1)
    end
  end
end
