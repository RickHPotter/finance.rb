# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Conversations", type: :request do
  let(:user) { create(:user, :random) }
  let(:other_user) { create(:user, :random) }

  before { sign_in user }

  describe "[ #index ]" do
    it "renders successfully" do
      human_conversation = Conversation.find_or_create_human_between!(user, other_user)
      assistant_conversation = Conversation.find_or_create_assistant_between!(sender: other_user, receiver: user)

      get conversations_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include(human_conversation.title_for(user))
      expect(response.body).to include(assistant_conversation.title_for(user))
    end

    it "filters conversations by unread, human, and assistant" do
      human_conversation = Conversation.find_or_create_human_between!(user, other_user)
      assistant_conversation = Conversation.find_or_create_assistant_between!(sender: other_user, receiver: user)
      human_conversation.messages.create!(user: other_user, body: "Unread human")
      assistant_conversation.messages.create!(user:, body: "Read assistant", read_at: Time.current)

      get conversations_path(filter: "unread")

      expect(response.body).to include(human_conversation.title_for(user))
      expect(response.body).not_to include(assistant_conversation.title_for(user))

      get conversations_path(filter: "human")

      expect(response.body).to include(human_conversation.title_for(user))
      expect(response.body).not_to include(assistant_conversation.title_for(user))

      get conversations_path(filter: "assistant")

      expect(response.body).to include(assistant_conversation.title_for(user))
      expect(response.body).not_to include(human_conversation.title_for(user))
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

    it "does not allow access to conversations outside the current user scope" do
      outsider_conversation = Conversation.find_or_create_human_between!(other_user, create(:user, :random))

      get conversation_path(outsider_conversation)

      expect(response).to have_http_status(:not_found)
    end
  end
end
