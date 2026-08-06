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
        expect(flash[:notice]).to eq(I18n.t("friendships.notices.request_sent"))

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
        expect(flash[:alert]).to eq(I18n.t("friendships.alerts.user_not_found"))
      end
    end
  end

  describe "PATCH /friendships/:public_id" do
    let!(:friendship) { create(:friendship, user: friend, friend: user, state: "pending") }

    it "accepts the request and creates an audit trail" do
      expect do
        patch "/friendships/#{friendship.public_id}", params: { state: "accepted" }
      end.to change(AuditOperation, :count).by(1)
                                           .and change(AuditVersion, :count).by(1)

      expect(response).to redirect_to(friendships_path)
      expect(flash[:notice]).to eq(I18n.t("friendships.notices.request_accepted"))
      expect(friendship.reload.state).to eq("accepted")

      version = AuditVersion.last
      expect(version.item).to eq(friendship)
      expect(version.event).to eq("update")
      expect(AuditOperation.find(version.operation_id).source).to eq("web")
    end

    it "rejects the request and creates an audit trail" do
      expect do
        patch "/friendships/#{friendship.public_id}", params: { state: "rejected" }
      end.to change(AuditOperation, :count).by(1)
                                           .and change(AuditVersion, :count).by(1)

      expect(response).to redirect_to(friendships_path)
      expect(flash[:notice]).to eq(I18n.t("friendships.notices.request_rejected"))
      expect(friendship.reload.state).to eq("rejected")

      version = AuditVersion.last
      expect(version.item).to eq(friendship)
      expect(version.event).to eq("update")
      expect(AuditOperation.find(version.operation_id).source).to eq("web")
    end

    it "blocks the user and creates an audit trail" do
      expect do
        patch "/friendships/#{friendship.public_id}", params: { state: "blocked" }
      end.to change(AuditOperation, :count).by(1)
                                           .and change(AuditVersion, :count).by(1)

      expect(response).to redirect_to(friendships_path)
      expect(flash[:notice]).to eq(I18n.t("friendships.notices.user_blocked"))
      expect(friendship.reload.state).to eq("blocked")

      version = AuditVersion.last
      expect(version.item).to eq(friendship)
      expect(version.event).to eq("update")
      expect(AuditOperation.find(version.operation_id).source).to eq("web")
    end
  end

  describe "DELETE /friendships/:public_id" do
    context "when friendship is pending and user is the sender" do
      let!(:friendship) { create(:friendship, user: user, friend: friend, state: "pending") }

      it "cancels the request and creates an audit trail" do
        expect do
          delete "/friendships/#{friendship.public_id}"
        end.to change(AuditOperation, :count).by(1)
                                             .and change(AuditVersion, :count).by(1)

        expect(response).to redirect_to(friendships_path)
        expect(flash[:notice]).to eq(I18n.t("friendships.notices.cancelled"))
        expect(friendship.reload.state).to eq("removed")
      end
    end

    context "when friendship is pending and user is the recipient" do
      let!(:friendship) { create(:friendship, user: friend, friend: user, state: "pending") }

      it "does not allow cancellation and returns an alert" do
        expect do
          delete "/friendships/#{friendship.public_id}"
        end.not_to change(AuditOperation, :count)

        expect(response).to redirect_to(friendships_path)
        expect(flash[:alert]).to eq(I18n.t("friendships.alerts.cannot_cancel"))
        expect(friendship.reload.state).to eq("pending")
      end
    end

    context "when friendship is accepted" do
      let!(:friendship) { create(:friendship, user: user, friend: friend, state: "accepted") }

      it "removes the friendship and creates an audit trail" do
        expect do
          delete "/friendships/#{friendship.public_id}"
        end.to change(AuditOperation, :count).by(1)
                                             .and change(AuditVersion, :count).by(1)

        expect(response).to redirect_to(friendships_path)
        expect(flash[:notice]).to eq(I18n.t("friendships.notices.removed"))
        expect(friendship.reload.state).to eq("removed")

        version = AuditVersion.last
        expect(version.item).to eq(friendship)
        expect(version.event).to eq("update")
        expect(AuditOperation.find(version.operation_id).source).to eq("web")
      end
    end
  end
end
