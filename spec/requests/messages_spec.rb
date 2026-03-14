# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Messages", type: :request do
  let(:user) { create(:user, :random) }
  let(:other_user) { create(:user, :random) }
  let(:conversation) do
    Conversation.create!.tap do |c|
      c.conversation_participants.create!(user:)
      c.conversation_participants.create!(user: other_user)
    end
  end

  before { sign_in user }

  describe "[ #create ]" do
    it "creates a message for the conversation" do
      expect do
        post conversation_messages_path(conversation), params: {
          message: { body: "Hello there" }
        }, headers: turbo_stream_headers
      end.to change(Message, :count).by(1)

      message = Message.last

      expect(message.conversation).to eq(conversation)
      expect(message.user).to eq(user)
      expect(message.body).to eq("Hello there")
    end
  end
end
