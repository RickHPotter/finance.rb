# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Conversations", type: :request do
  let(:user) { create(:user, :random) }
  let(:other_user) { create(:user, :random) }

  before { sign_in user }

  describe "[ #index ]" do
    it "renders successfully" do
      human_conversation = Conversation.find_or_create_human_between!(user, other_user)
      assistant_conversation = Conversation.find_or_create_assistant_between!(other_user, user)

      get conversations_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include(human_conversation.title_for(user))
      expect(response.body).to include(assistant_conversation.title_for(user))
    end

    it "filters conversations by unread, human, and assistant" do
      human_conversation = Conversation.find_or_create_human_between!(user, other_user)
      assistant_conversation = Conversation.find_or_create_assistant_between!(other_user, user)
      human_conversation.messages.create!(user: other_user, body: "Unread human")
      assistant_conversation.messages.create!(user:, body: "Read assistant", read_at: Time.current)

      get conversations_path(filter: "unread")

      expect(response.body).to include(conversation_path(human_conversation))
      expect(response.body).not_to include(conversation_path(assistant_conversation))

      get conversations_path(filter: "human")

      expect(response.body).to include(conversation_path(human_conversation))
      expect(response.body).not_to include(conversation_path(assistant_conversation))

      get conversations_path(filter: "assistant")

      expect(response.body).to include(conversation_path(assistant_conversation))
      expect(response.body).not_to include(conversation_path(human_conversation))
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

    it "hides the composer and defaults assistant threads to pending messages" do
      conversation = Conversation.find_or_create_assistant_between!(user, other_user)
      create(:cash_transaction, user:, user_bank_account: create(:user_bank_account, user:, bank: create(:bank, :random))).tap do |local_reference|
        local_reference.update_columns(reference_transactable_type: "CashTransaction", reference_transactable_id: 999)
      end
      pending_message = conversation.messages.create!(
        user: other_user,
        body: "notification:update",
        headers: {
          version: "message_notification_v2",
          event: { action: "update", receiver_first_name: user.first_name, transaction_type: "CashTransaction", details: { description: "Pending notification" } },
          replay: { id: 999, type: "CashTransaction" }
        }.to_json
      )
      applied_message = conversation.messages.create!(
        user: other_user,
        body: "notification:create",
        applied_at: Time.current,
        headers: {
          version: "message_notification_v2",
          event: { action: "create", receiver_first_name: user.first_name, transaction_type: "CashTransaction", details: { description: "Applied notification" } },
          replay: { id: 111, type: "CashTransaction" }
        }.to_json
      )

      get conversation_path(conversation)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Pending notification")
      expect(response.body).not_to include("Applied notification")
      expect(response.body).not_to include(Message.human_attribute_name(:body_placeholder))
      expect(pending_message.reload.read_at).to be_present
      expect(applied_message.reload.read_at).to be_present
      expect(response.body).to include(Conversation.human_attribute_name(:all))
      expect(response.body).to include(Conversation.human_attribute_name(:pending))
      expect(response.body).to include(Conversation.human_attribute_name(:mine))
      expect(response.body).to include(Conversation.human_attribute_name(:theirs))
    end

    it "shows only actionable assistant messages on pending" do
      conversation = Conversation.find_or_create_assistant_between!(user, other_user)
      local_reference = create(:cash_transaction, user:, user_bank_account: create(:user_bank_account, user:, bank: create(:bank, :random)))
      local_reference.update_columns(reference_transactable_type: "CashTransaction", reference_transactable_id: 999)

      conversation.messages.create!(
        user: other_user,
        body: "notification:create",
        headers: {
          version: "message_notification_v2",
          event: { action: "create", receiver_first_name: user.first_name, transaction_type: "CashTransaction", details: { description: "Create me" } },
          replay: { id: 111, type: "CashTransaction" }
        }.to_json
      )
      conversation.messages.create!(
        user: other_user,
        body: "notification:update",
        headers: {
          version: "message_notification_v2",
          event: { action: "update", receiver_first_name: user.first_name, transaction_type: "CashTransaction", details: { description: "Correct me" } },
          replay: { id: 999, type: "CashTransaction" }
        }.to_json
      )
      destroy_target = create(:cash_transaction, user:, user_bank_account: create(:user_bank_account, user:, bank: create(:bank, :random)))
      conversation.messages.create!(
        user: other_user,
        body: "notification:destroy",
        reference_transactable: destroy_target,
        headers: {
          version: "message_notification_v2",
          event: { action: "destroy", receiver_first_name: user.first_name, transaction_type: "CashTransaction", details: { description: "Destroy me" } },
          replay: nil
        }.to_json
      )
      conversation.messages.create!(
        user: other_user,
        body: "notification:create",
        applied_at: Time.current,
        headers: {
          version: "message_notification_v2",
          event: { action: "create", receiver_first_name: user.first_name, transaction_type: "CashTransaction", details: { description: "Applied already" } },
          replay: { id: 222, type: "CashTransaction" }
        }.to_json
      )
      outdated_message = conversation.messages.create!(
        user: other_user,
        body: "notification:update",
        headers: {
          version: "message_notification_v2",
          event: { action: "update", receiver_first_name: user.first_name, transaction_type: "CashTransaction", details: { description: "Outdated" } },
          replay: { id: 333, type: "CashTransaction" }
        }.to_json
      )
      superseding_message = conversation.messages.create!(
        user: other_user,
        body: "notification:update",
        headers: {
          version: "message_notification_v2",
          event: { action: "update", receiver_first_name: user.first_name, transaction_type: "CashTransaction", details: { description: "Latest" } },
          replay: { id: 444, type: "CashTransaction" }
        }.to_json
      )
      outdated_message.update!(superseded_by: superseding_message)
      conversation.messages.create!(
        user: other_user,
        body: "notification:create",
        headers: {
          version: "message_notification_v2",
          event: { action: "create", receiver_first_name: user.first_name, transaction_type: "CashTransaction", details: { description: "Edit me" } },
          replay: { id: 999, type: "CashTransaction" }
        }.to_json
      )

      get conversation_path(conversation, message_filter: "pending")

      expect(response.body).to include("Create me")
      expect(response.body).to include("Correct me")
      expect(response.body).to include("Destroy me")
      expect(response.body).to include("Latest")
      expect(response.body).not_to include("Applied already")
      expect(response.body).not_to include("Outdated")
      expect(response.body).not_to include("Edit me")
    end

    it "renders distinct assistant message sides for my notifications and the other user's notifications" do
      conversation = Conversation.find_or_create_assistant_between!(user, other_user)
      conversation.messages.create!(
        user: user,
        body: "notification:update",
        headers: {
          version: "message_notification_v2",
          event: { action: "update", receiver_first_name: other_user.first_name, transaction_type: "CashTransaction", details: {} },
          replay: { id: 1, type: "CashTransaction" }
        }.to_json
      )
      conversation.messages.create!(
        user: other_user,
        body: "notification:update",
        headers: {
          version: "message_notification_v2",
          event: { action: "update", receiver_first_name: user.first_name, transaction_type: "CashTransaction", details: {} },
          replay: { id: 2, type: "CashTransaction" }
        }.to_json
      )

      get conversation_path(conversation, message_filter: "all")

      expect(response.body).to include('data-presenter-side="self"')
      expect(response.body).to include('data-presenter-side="other"')
      expect(response.body).to include(Conversation.human_attribute_name(:your_assistant))
      expect(response.body).to include(ERB::Util.html_escape(I18n.t("activerecord.attributes.conversation.assistant_of", name: other_user.first_name)))
    end

    it "filters assistant messages by mine and theirs" do
      conversation = Conversation.find_or_create_assistant_between!(user, other_user)
      conversation.messages.create!(
        user: user,
        body: "notification:update",
        headers: {
          version: "message_notification_v2",
          event: { action: "update", receiver_first_name: other_user.first_name, transaction_type: "CashTransaction", details: { description: "Mine only" } },
          replay: { id: 1, type: "CashTransaction" }
        }.to_json
      )
      conversation.messages.create!(
        user: other_user,
        body: "notification:update",
        headers: {
          version: "message_notification_v2",
          event: { action: "update", receiver_first_name: user.first_name, transaction_type: "CashTransaction", details: { description: "Theirs only" } },
          replay: { id: 2, type: "CashTransaction" }
        }.to_json
      )

      get conversation_path(conversation, message_filter: "all", message_side: [ "mine" ])

      expect(response.body).to include("Mine only")
      expect(response.body).not_to include("Theirs only")

      get conversation_path(conversation, message_filter: "all", message_side: [ "theirs" ])

      expect(response.body).not_to include("Mine only")
      expect(response.body).to include("Theirs only")
    end

    it "does not allow access to conversations outside the current user scope" do
      outsider_conversation = Conversation.find_or_create_human_between!(other_user, create(:user, :random))

      get conversation_path(outsider_conversation)

      expect(response).to have_http_status(:not_found)
    end
  end
end
