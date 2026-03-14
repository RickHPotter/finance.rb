# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Subscriptions", type: :request do
  let(:user) { create(:user, :random) }

  before { sign_in user }

  describe "[ #create ]" do
    it "creates a subscription" do
      expect do
        post subscriptions_path, params: {
          subscription: {
            endpoint: "https://example.com/push/1",
            keys: { p256dh: "public-key", auth: "auth-key" }
          }
        }
      end.to change(Subscription, :count).by(1)

      subscription = Subscription.last

      expect(subscription.endpoint).to eq("https://example.com/push/1")
      expect(subscription.p256dh).to eq("public-key")
      expect(subscription.auth).to eq("auth-key")
      expect(response).to have_http_status(:ok)
    end

    it "updates an existing subscription with the same endpoint" do
      create(:subscription, user:, endpoint: "https://example.com/push/1", p256dh: "old", auth: "old")

      expect do
        post subscriptions_path, params: {
          subscription: {
            endpoint: "https://example.com/push/1",
            keys: { p256dh: "new-key", auth: "new-auth" }
          }
        }
      end.not_to change(Subscription, :count)

      subscription = user.subscriptions.find_by(endpoint: "https://example.com/push/1")

      expect(subscription.p256dh).to eq("new-key")
      expect(subscription.auth).to eq("new-auth")
      expect(response).to have_http_status(:ok)
    end
  end
end
