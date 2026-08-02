# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Friendships", type: :request do
  let(:user) { create(:user, email: "user#{SecureRandom.hex(4)}@example.com") }
  let(:friend) { create(:user, email: "friend#{SecureRandom.hex(4)}@example.com") }

  before do
    sign_in user
  end

  describe "GET /friendships" do
    it "returns http success" do
      get "/friendships"
      expect(response).to have_http_status(:success)
    end
  end

  describe "POST /friendships" do
    context "with valid friend public_id" do
      it "creates a pending friendship request" do
        post "/friendships", params: { friend_public_id: friend.public_id }
        expect(response).to redirect_to(friendships_path)
        expect(flash[:notice]).to eq("Friend request sent.")

        friendship = Friendship.last
        expect(friendship.user).to eq(user)
        expect(friendship.friend).to eq(friend)
        expect(friendship.state).to eq("pending")
      end
    end

    context "with invalid friend" do
      it "does not create request and redirects with alert" do
        post "/friendships", params: { friend_public_id: "invalid" }
        expect(response).to redirect_to(friendships_path)
        expect(flash[:alert]).to eq("User not found.")
      end
    end
  end

  describe "PATCH /friendships/:public_id" do
    let!(:friendship) { create(:friendship, user: friend, friend: user, state: "pending") }

    it "accepts the request" do
      patch "/friendships/#{friendship.public_id}", params: { state: "accepted" }
      expect(response).to redirect_to(friendships_path)
      expect(flash[:notice]).to eq("Friend request accepted.")
      expect(friendship.reload.state).to eq("accepted")
    end

    it "rejects the request" do
      patch "/friendships/#{friendship.public_id}", params: { state: "rejected" }
      expect(response).to redirect_to(friendships_path)
      expect(flash[:notice]).to eq("Friend request rejected.")
      expect(friendship.reload.state).to eq("rejected")
    end
  end

  describe "DELETE /friendships/:public_id" do
    let!(:friendship) { create(:friendship, user: user, friend: friend, state: "accepted") }

    it "removes the friendship" do
      delete "/friendships/#{friendship.public_id}"
      expect(response).to redirect_to(friendships_path)
      expect(flash[:notice]).to eq("Friendship removed.")
      expect(friendship.reload.state).to eq("removed")
    end
  end
end
