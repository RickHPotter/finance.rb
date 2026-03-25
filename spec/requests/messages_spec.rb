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

    it "creates a message inside a derived-scenario conversation" do
      derived_context = create(:context, user:, name: "Message Scenario", source_context: user.main_context)
      derived_conversation = Conversation.find_or_create_human_between!(user, other_user, scenario_key: derived_context.scenario_key)

      patch switch_context_path(derived_context)

      expect do
        post conversation_messages_path(derived_conversation), params: {
          message: { body: "Derived hello" }
        }, headers: turbo_stream_headers
      end.to change(Message, :count).by(1)

      expect(Message.last.conversation).to eq(derived_conversation)
    end

    it "does not allow posting to a conversation from another scenario" do
      derived_context = create(:context, user:, name: "Message Access", source_context: user.main_context)

      patch switch_context_path(derived_context)

      post conversation_messages_path(conversation), params: {
        message: { body: "Wrong place" }
      }, headers: turbo_stream_headers

      expect(response).to have_http_status(:not_found)
    end
  end
end
