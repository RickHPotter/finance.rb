# frozen_string_literal: true

require "rails_helper"

RSpec.describe "PushSubscriptions", type: :request do
  let(:user) { create(:user, :random) }

  before { sign_in user }

  describe "[ #create ]" do
    it "creates a push subscription" do
      expect do
        post push_subscriptions_path, params: {
          push_subscription: {
            endpoint: "https://example.com/push/1",
            keys: { p256dh: "public-key", auth: "auth-key" }
          }
        }
      end.to change(PushSubscription, :count).by(1)

      push_subscription = PushSubscription.last

      expect(push_subscription.endpoint).to eq("https://example.com/push/1")
      expect(push_subscription.p256dh).to eq("public-key")
      expect(push_subscription.auth).to eq("auth-key")
      expect(response).to have_http_status(:ok)
    end

    it "updates an existing push subscription with the same endpoint" do
      create(:push_subscription, user:, endpoint: "https://example.com/push/1", p256dh: "old", auth: "old")

      expect do
        post push_subscriptions_path, params: {
          push_subscription: {
            endpoint: "https://example.com/push/1",
            keys: { p256dh: "new-key", auth: "new-auth" }
          }
        }
      end.not_to change(PushSubscription, :count)

      push_subscription = user.push_subscriptions.find_by(endpoint: "https://example.com/push/1")

      expect(push_subscription.p256dh).to eq("new-key")
      expect(push_subscription.auth).to eq("new-auth")
      expect(response).to have_http_status(:ok)
    end
  end
end
