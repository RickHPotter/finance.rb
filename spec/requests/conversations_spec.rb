# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Conversations", type: :request do
  let(:user) { create(:user, :random) }
  let(:other_user) { create(:user, :random) }

  before { sign_in user }

  describe "[ #index ]" do
    it "renders successfully" do
      get conversations_path

      expect(response).to have_http_status(:success)
    end
  end

  describe "[ #create ]" do
    it "creates a conversation and redirects to show" do
      post conversations_path, params: {
        conversation_participants_attributes: [
          { user_id: user.id },
          { user_id: other_user.id }
        ]
      }

      conversation = Conversation.last

      expect(response).to redirect_to(conversation_path(conversation))
    end
  end

  describe "[ #show ]" do
    it "marks unread messages from other users as read" do
      conversation = Conversation.create!
      conversation.conversation_participants.create!(user:)
      conversation.conversation_participants.create!(user: other_user)
      message = conversation.messages.create!(user: other_user, body: "Hello")

      get conversation_path(conversation)

      expect(response).to have_http_status(:success)
      expect(message.reload.read_at).to be_present
    end
  end
end
