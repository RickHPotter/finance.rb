# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Conversations", type: :request do
  let(:user) { create(:user, :random) }
  let(:other_user) { create(:user, :random) }
  let!(:friendship) { create(:friendship, :accepted, user:, friend: other_user) }

  before { sign_in user }

  describe "[ #index ]" do
    it "renders successfully" do
      human_conversation = resolve_human_conversation(user, other_user)
      assistant_conversation = resolve_assistant_conversation(other_user, user)

      get conversations_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include(human_conversation.title_for(user))
      expect(response.body).to include(assistant_conversation.title_for(user))
    end

    it "filters conversations by unread, human, and assistant" do
      human_conversation = resolve_human_conversation(user, other_user)
      assistant_conversation = resolve_assistant_conversation(other_user, user)
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

    it "orders cards by latest activity and id without grouping conversation kinds" do
      older_human = resolve_human_conversation(user, other_user)
      newer_assistant = resolve_assistant_conversation(other_user, user)
      older_human.messages.create!(user: other_user, body: "Older activity", created_at: 2.hours.ago)
      newer_assistant.messages.create!(user: other_user, body: "Newer activity", created_at: 1.hour.ago)

      get conversations_path

      card_ids = Nokogiri::HTML(response.body).css("[data-conversation-id]").map { |node| node["data-conversation-id"] }.uniq
      expect(card_ids).to eq([ newer_assistant.public_id, older_human.public_id ])
    end

    it "loads later conversation cursor pages into a dedicated frame" do
      stub_const("Logic::Conversations::Page::DEFAULT_SIZE", 2)
      conversations = [ resolve_human_conversation(user, other_user) ]
      2.times do
        friend = create(:user, :random)
        create(:friendship, :accepted, user:, friend:)
        conversations << resolve_human_conversation(user, friend)
      end
      conversations.each { |conversation| conversation.update_columns(last_message_at: Time.zone.local(2026, 8, 20, 12)) }

      get conversations_path

      document = Nokogiri::HTML(response.body)
      first_page_ids = document.css("[data-conversation-id]").map { |node| node["data-conversation-id"] }
      next_link = document.at_css("[data-conversation-page=next]")
      expect(first_page_ids).to eq(conversations.last(2).reverse.map(&:public_id))

      get next_link["href"], headers: { "Turbo-Frame" => next_link["data-turbo-frame"] }

      next_document = Nokogiri::HTML(response.body)
      expect(next_document.at_css("turbo-frame##{next_link['data-turbo-frame']}")).to be_present
      expect(next_document.css("[data-conversation-id]").map { |node| node["data-conversation-id"] }).to eq([ conversations.first.public_id ])
    end

    it "renders profile display names with attached and fallback avatars" do
      other_user.profile.update!(first_name: "Gigi", last_name: "February")
      other_user.profile.avatar.attach(io: StringIO.new("avatar"), filename: "gigi.png", content_type: "image/png")
      resolve_human_conversation(user, other_user)

      fallback_friend = create(:user, :random)
      create(:friendship, :accepted, user:, friend: fallback_friend)
      resolve_human_conversation(user, fallback_friend)

      get conversations_path

      document = Nokogiri::HTML(response.body)
      expect(document.at_css('img[data-profile-avatar="attached"][alt="Gigi February"]')).to be_present
      expect(document.at_css("img[data-profile-avatar=\"fallback\"][alt=\"#{fallback_friend.display_name}\"]")).to be_present
      expect(response.body).to include("Gigi February")
    end

    it "isolates archived and muted participant filters" do
      archived_conversation = resolve_human_conversation(user, other_user)
      muted_friend = create(:user, :random)
      create(:friendship, :accepted, user:, friend: muted_friend)
      muted_conversation = resolve_human_conversation(user, muted_friend)
      archived_conversation.participant_for!(user).update!(archived_at: Time.current)
      muted_conversation.participant_for!(user).update!(muted_at: Time.current)

      get conversations_path(filter: "archived")

      expect(response.body).to include(conversation_path(archived_conversation))
      expect(response.body).not_to include(conversation_path(muted_conversation))

      get conversations_path(filter: "muted")

      expect(response.body).to include(conversation_path(muted_conversation))
      expect(response.body).not_to include(conversation_path(archived_conversation))
    end

    it "dismisses the tab notification dot for unread muted conversations without clearing unread state" do
      conversation = resolve_human_conversation(user, other_user)
      conversation.messages.create!(user: other_user, body: "Unread but quiet")

      get conversations_path

      conversation_tab = controller.instance_variable_get(:@profile_tab).find { |item| item.link == conversations_path }
      expect(conversation_tab.notification_type).to eq(1)

      conversation.participant_for!(user).update!(muted_at: Time.current)
      get conversations_path

      conversation_tab = controller.instance_variable_get(:@profile_tab).find { |item| item.link == conversations_path }
      expect(conversation_tab.notification_type).to eq(0)
      expect(Logic::Conversations::Policy.scope(user:, context: user.main_context).with_unread_for(user)).to contain_exactly(conversation)

      get conversations_path(filter: "unread")
      expect(response.body).to include(conversation_path(conversation))
    end

    it "shows the selected main scenario and participant controls on every card" do
      conversation = resolve_human_conversation(user, other_user)

      get conversations_path

      document = Nokogiri::HTML(response.body)
      expect(document.at_css("[data-conversation-scenario]").text).to include(I18n.t("contexts.index.main_label"))
      card = document.at_css("[data-conversation-id=\"#{conversation.public_id}\"]")
      expect(card.at_css("[data-conversation-action=archive]")).to be_present
      expect(card.at_css("[data-conversation-action=mute]")).to be_present
    end

    it "retains revoked history without exposing it in lists or unread counts" do
      conversation = resolve_human_conversation(user, other_user)
      message = conversation.messages.create!(user: other_user, body: "Retained revoked history")
      friendship.update!(state: "blocked")
      sign_in user

      get conversations_path

      expect(response).to have_http_status(:success)
      expect(response.body).not_to include(conversation_path(conversation))
      expect(Message.exists?(message.id)).to be(true)
      expect(Logic::Conversations::Policy.scope(user:, context: user.main_context).with_unread_for(user)).to be_empty
    end

    it "shows only conversations for the current scenario" do
      main_conversation = resolve_human_conversation(user, other_user)
      derived_context = create(:context, user:, name: "Conversation Scenario", source_context: user.main_context)
      create(:context, user: other_user, scenario_key: derived_context.scenario_key)
      derived_conversation = resolve_human_conversation(user, other_user, scenario_key: derived_context.scenario_key)

      patch switch_context_path(derived_context)
      get conversations_path

      expect(response.body).to include(conversation_path(derived_conversation))
      expect(response.body).not_to include(conversation_path(main_conversation))
    end

    it "keeps unread filtering isolated between main and derived scenarios" do
      main_conversation = resolve_assistant_conversation(other_user, user)
      derived_context = create(:context, user:, name: "Unread Scenario", source_context: user.main_context)
      create(:context, user: other_user, scenario_key: derived_context.scenario_key)
      derived_conversation = resolve_assistant_conversation(other_user, user, scenario_key: derived_context.scenario_key)

      main_conversation.messages.create!(user: other_user, body: "notification:create", headers: {
        version: "message_notification_v2",
        event: { action: "create", receiver_first_name: user.first_name, transaction_type: "CashTransaction", details: { description: "Main unread" } },
        replay: { id: 1, type: "CashTransaction" }
      }.to_json)
      derived_conversation.messages.create!(user: other_user, body: "notification:create", headers: {
        version: "message_notification_v2",
        event: { action: "create", receiver_first_name: user.first_name, transaction_type: "CashTransaction", details: { description: "Derived unread" } },
        replay: { id: 2, type: "CashTransaction" }
      }.to_json)

      get conversations_path(filter: "unread")

      expect(response.body).to include(conversation_path(main_conversation))
      expect(response.body).not_to include(conversation_path(derived_conversation))

      patch switch_context_path(derived_context)
      get conversations_path(filter: "unread")

      expect(response.body).to include(conversation_path(derived_conversation))
      expect(response.body).not_to include(conversation_path(main_conversation))
    end
  end

  describe "[ #new ]" do
    it "lists accepted friends by profile identity and posts only the friendship public id" do
      other_user.profile.update!(first_name: "Rikki", last_name: "Friend")
      pending_friend = create(:user, :random)
      create(:friendship, user:, friend: pending_friend, state: "pending")

      get new_conversation_path

      expect(response).to have_http_status(:success)
      document = Nokogiri::HTML(response.body)
      expect(response.body).to include("Rikki Friend")
      expect(response.body).not_to include(pending_friend.display_name)
      form = document.at_css("form[action*='friendship_public_id']")
      expect(form["action"]).to include(friendship.public_id)
      expect(form["action"]).not_to include("user_id")
    end

    it "shows an empty state when no accepted friend is available in the selected scenario" do
      friendship.update!(state: "removed")
      sign_in user

      get new_conversation_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include(Conversation.human_attribute_name(:no_available_friends))
    end

    it "omits a friend until both participants have the selected derived scenario" do
      derived_context = create(:context, user:, name: "Private scenario", source_context: user.main_context)
      patch switch_context_path(derived_context)

      get new_conversation_path
      expect(response.body).not_to include(other_user.display_name)

      create(:context, user: other_user, scenario_key: derived_context.scenario_key)
      get new_conversation_path
      expect(response.body).to include(other_user.display_name)
    end
  end

  describe "[ #create ]" do
    it "creates a conversation and redirects to show" do
      post conversations_path, params: {
        friendship_public_id: friendship.public_id
      }

      conversation = Conversation.last

      expect(response).to redirect_to(conversation_path(conversation))
    end

    it "creates conversations inside the current scenario" do
      derived_context = create(:context, user:, name: "Conversation Create", source_context: user.main_context)
      create(:context, user: other_user, scenario_key: derived_context.scenario_key)

      patch switch_context_path(derived_context)

      post conversations_path, params: {
        friendship_public_id: friendship.public_id
      }

      expect(Conversation.last.scenario_key).to eq(derived_context.scenario_key)
    end

    it "derives participants from the accepted friendship and ignores forged user ids" do
      outsider = create(:user, :random)

      post conversations_path, params: {
        friendship_public_id: friendship.public_id,
        conversation_participants_attributes: [ { user_id: outsider.id } ]
      }

      expect(Conversation.last.users.order(:id)).to eq([ user, other_user ].sort_by(&:id))
      expect(Conversation.last.users).not_to include(outsider)
    end

    it "creates the same canonical thread when the current user is either friendship side" do
      owner = create(:user, :random)
      reverse_friendship = create(:friendship, :accepted, user: owner, friend: user)

      post conversations_path, params: { friendship_public_id: reverse_friendship.public_id }

      conversation = Conversation.find_by!(friendship: reverse_friendship, kind: :human, scenario_key: nil)
      expect(response).to redirect_to(conversation_path(conversation))
      expect(conversation.users.order(:id)).to eq([ user, owner ].sort_by(&:id))
    end

    it "denies outsider friendship identifiers and every non-accepted friendship state" do
      outsider = create(:user, :random)
      outsider_friend = create(:user, :random)
      outsider_friendship = create(:friendship, :accepted, user: outsider, friend: outsider_friend)

      expect do
        post conversations_path, params: { friendship_public_id: outsider_friendship.public_id }
      end.not_to change(Conversation, :count)
      expect(response).to have_http_status(:not_found)

      %w[pending rejected blocked removed].each do |state|
        friendship.update!(state:)
        sign_in user

        expect do
          post conversations_path, params: { friendship_public_id: friendship.public_id }
        end.not_to change(Conversation, :count)
        expect(response).to have_http_status(:not_found), "expected #{state} friendship creation to be denied, got #{response.status} #{response.location}"
      end
    end
  end

  describe "[ #show ]" do
    it "renders profile identity, controls, main scenario, and a human empty state" do
      other_user.profile.update!(first_name: "Gigi", last_name: "Conversation")
      conversation = resolve_human_conversation(user, other_user)

      get conversation_path(conversation)

      document = Nokogiri::HTML(response.body)
      expect(response.body).to include("Gigi Conversation")
      expect(document.at_css("[data-conversation-back=true]")).to be_nil
      expect(document.at_css("[data-conversation-action=archive]")).to be_present
      expect(document.at_css("[data-conversation-action=mute]")).to be_present
      expect(document.at_css(".conversation-message-scroll")).to be_present
      expect(document.at_css("[data-conversation-scenario]").text).to include(I18n.t("contexts.index.main_label"))
      expect(document.at_css("[data-conversation-empty=human]")).to be_present
      composer = document.at_css("form#messages_conversation_#{conversation.id}")
      expect(composer.at_css("textarea[name='message[body]']")["class"]).to include("dark:bg-slate-950", "dark:text-slate-100", "focus:border-emerald-500")
      expect(composer.at_css("input[type=submit]")["class"]).to include("dark:bg-emerald-500", "dark:text-slate-950", "focus-visible:ring-emerald-500")
    end

    it "includes the conversation as return navigation on actionable transaction links" do
      conversation = resolve_assistant_conversation(user, other_user)
      local_reference = create(:cash_transaction, user:, context: user.main_context,
                                                  user_bank_account: create(:user_bank_account, user:, bank: create(:bank, :random)))
      local_reference.update_columns(reference_transactable_type: "CashTransaction", reference_transactable_id: 987_654)
      message = conversation.messages.create!(
        user: other_user,
        body: "notification:update",
        headers: {
          version: "message_notification_v2",
          event: { action: "update", transaction_type: "CashTransaction", details: {} },
          replay: { id: 987_654, type: "CashTransaction" }
        }.to_json
      )

      get conversation_path(conversation, message_filter: "all")

      href = Nokogiri::HTML(response.body).at_css("turbo-frame#message_#{message.id} [data-message-action=correct]")["href"]
      return_to = Rack::Utils.parse_nested_query(URI.parse(href).query).fetch("return_to")
      expect(return_to).to start_with(conversation_path(conversation))
      expect(return_to).to include("message_filter=all")
    end

    it "marks unread messages from other users as read" do
      conversation = resolve_human_conversation(user, other_user)
      message = conversation.messages.create!(user: other_user, body: "Hello")

      get conversation_path(conversation)

      expect(response).to have_http_status(:success)
      expect(message.reload.read_at).to be_present
    end

    it "loads the newest bounded page first and prepends older messages without advancing the read cursor" do
      conversation = resolve_human_conversation(user, other_user)
      started_at = Time.zone.local(2026, 8, 20, 8)
      messages = 42.times.map do |index|
        conversation.messages.create!(user: other_user, body: "Page message #{index}", created_at: started_at + index.minutes)
      end

      get conversation_path(conversation)

      document = Nokogiri::HTML(response.body)
      first_page_ids = document.css("[id^='message_entry_']").map { |node| node["id"].delete_prefix("message_entry_").to_i }
      older_link = document.at_css("[data-message-page=older]")
      cursor_after_newest_page = conversation.participant_for!(user).reload.last_read_message_id

      expect(first_page_ids).to eq(messages.last(40).map(&:id))
      expect(cursor_after_newest_page).to eq(messages.last.id)

      get older_link["href"], headers: { "Turbo-Frame" => older_link["data-turbo-frame"] }

      older_document = Nokogiri::HTML(response.body)
      older_ids = older_document.css("[id^='message_entry_']").map { |node| node["id"].delete_prefix("message_entry_").to_i }
      expect(older_ids).to eq(messages.first(2).map(&:id))
      expect(conversation.participant_for!(user).reload.last_read_message_id).to eq(cursor_after_newest_page)
    end

    it "marks unread superseded predecessors at the same time as their replacement" do
      conversation = resolve_assistant_conversation(user, other_user)
      original_read_at = 2.days.ago.change(usec: 0)
      already_read_predecessor = conversation.messages.create!(
        user: other_user,
        body: "Already read predecessor",
        read_at: original_read_at,
        auto_applied: true
      )
      unread_predecessor = conversation.messages.create!(
        user: other_user,
        body: "Unread predecessor",
        auto_applied: true
      )
      replacement = conversation.messages.create!(user: other_user, body: "Current replacement")
      already_read_predecessor.update!(superseded_by: replacement)
      unread_predecessor.update!(superseded_by: replacement)

      get conversation_path(conversation)

      replacement_read_at = replacement.reload.read_at
      expect(replacement_read_at).to be_present
      expect(unread_predecessor.reload.read_at).to eq(replacement_read_at)
      expect(already_read_predecessor.reload.read_at).to eq(original_read_at)
    end

    it "hides the composer and defaults assistant threads to pending messages" do
      conversation = resolve_assistant_conversation(user, other_user)
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
      header_sections = Nokogiri::HTML(response.body).css("[data-conversation-header-section]").map { |node| node["data-conversation-header-section"] }
      expect(header_sections).to eq(%w[participant-controls message-filters])
    end

    it "does not acknowledge an auto-applied message merely by opening the conversation" do
      conversation = resolve_assistant_conversation(user, other_user)
      message = conversation.messages.create!(
        user: other_user,
        body: "notification:update",
        applied_at: Time.current,
        auto_applied: true,
        headers: {
          version: "message_notification_v2",
          event: { action: "update", receiver_first_name: user.first_name, transaction_type: "CashTransaction", details: { description: "Still pending review" } },
          replay: { id: 999, type: "CashTransaction" }
        }.to_json
      )

      get conversation_path(conversation, message_filter: "pending")

      expect(response.body).to include("Still pending review")
      expect(message.reload.read_at).to be_nil
    end

    it "shows only OK and Revert for a safely revertible auto-applied message" do
      conversation = resolve_assistant_conversation(user, other_user)
      transaction = PaperTrail.request(enabled: false) do
        create(:cash_transaction, user:, context: user.main_context, user_bank_account: create(:user_bank_account, user:, bank: create(:bank, :random)))
      end
      operation = nil
      Audit::Operation.run(source: :actionable_message, actor: user, context: user.main_context) do
        transaction.update!(description: "Auto-applied state")
        operation = Audit::Operation.ensure_persisted!
      end
      message = conversation.messages.create!(
        user: other_user,
        body: "notification:update",
        applied_at: Time.current,
        auto_applied: true,
        audit_operation: operation,
        headers: {
          version: "message_notification_v2",
          event: { action: "update", receiver_first_name: user.first_name, transaction_type: "CashTransaction", details: { description: "Auto-applied state" } },
          replay: { id: 999, type: "CashTransaction" }
        }.to_json
      )

      get conversation_path(conversation, message_filter: "all")

      document = Nokogiri::HTML(response.body)
      actions = document.css("turbo-frame#message_#{message.id} [data-message-action]").map { |node| node["data-message-action"] }
      expect(actions).to contain_exactly("ok", "revert")
    end

    it "shows only Revert after a manual apply, and hides it after supersession" do
      conversation = resolve_assistant_conversation(user, other_user)
      transaction = PaperTrail.request(enabled: false) do
        create(:cash_transaction, user:, context: user.main_context, user_bank_account: create(:user_bank_account, user:, bank: create(:bank, :random)))
      end
      operation = nil
      Audit::Operation.run(source: :web, actor: user, context: user.main_context) do
        transaction.update!(description: "Manually applied state")
        operation = Audit::Operation.ensure_persisted!
      end
      message = conversation.messages.create!(
        user: other_user,
        body: "notification:update",
        applied_at: Time.current,
        audit_operation: operation,
        headers: {
          version: "message_notification_v2",
          event: { action: "update", receiver_first_name: user.first_name, transaction_type: "CashTransaction", details: { description: "Manually applied state" } },
          replay: { id: 999, type: "CashTransaction" }
        }.to_json
      )

      get conversation_path(conversation, message_filter: "all")

      document = Nokogiri::HTML(response.body)
      actions = document.css("turbo-frame#message_#{message.id} [data-message-action]").map { |node| node["data-message-action"] }
      expect(actions).to eq([ "revert" ])

      newer_message = conversation.messages.create!(user: other_user, body: "newer assistant message")
      message.update!(superseded_by: newer_message)
      get conversation_path(conversation, message_filter: "all")

      document = Nokogiri::HTML(response.body)
      expect(document.css("turbo-frame#message_#{message.id} [data-message-action]")).to be_empty
    end

    it "shows only actionable assistant messages on pending" do
      conversation = resolve_assistant_conversation(user, other_user)
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

    it "keeps paid-state notifications in pending until acknowledged" do
      conversation = resolve_assistant_conversation(user, other_user)
      message = conversation.messages.create!(
        user: other_user,
        body: "notification:paid_state",
        headers: {
          version: "message_paid_state_v1",
          event: {
            action: "paid",
            receiver_first_name: user.first_name,
            transaction_type: "CashTransaction",
            details: {
              transaction_label: "Cash transaction",
              description: "Shared return",
              installment_number: 1,
              installments_count: 1,
              date: "2026-03-26",
              paid: true
            }
          }
        }.to_json
      )

      get conversation_path(conversation, message_filter: "pending")

      expect(response.body).to include("Shared return")
      expect(response.body).to include(Message.human_attribute_name(:ok))

      patch apply_conversation_message_path(conversation, message), headers: turbo_stream_headers
      get conversation_path(conversation, message_filter: "pending")

      expect(response.body).not_to include("Shared return")
    end

    it "keeps pending assistant message resolution scoped to the current context" do
      conversation = resolve_assistant_conversation(user, other_user)
      bank = create(:bank, :random)
      user_bank_account = create(:user_bank_account, user:, bank:)
      create(:cash_transaction, user:, context: user.main_context, user_bank_account:).tap do |local_reference|
        local_reference.update_columns(reference_transactable_type: "CashTransaction", reference_transactable_id: 999)
      end
      derived_context = create(:context, user:, name: "Conversation Isolation", source_context: user.main_context)

      patch switch_context_path(derived_context)

      conversation.messages.create!(
        user: other_user,
        body: "notification:create",
        headers: {
          version: "message_notification_v2",
          event: { action: "create", receiver_first_name: user.first_name, transaction_type: "CashTransaction", details: { description: "Derived create me" } },
          replay: { id: 999, type: "CashTransaction" }
        }.to_json
      )

      get conversation_path(conversation, message_filter: "pending")

      expect(response.body).to include("Derived create me")
    end

    it "shows create instead of edit when the matching local reference only exists in another scenario" do
      local_reference = create(:cash_transaction, user:, context: user.main_context,
                                                  user_bank_account: create(:user_bank_account, user:, bank: create(:bank, :random))).tap do |local_reference|
        local_reference.update_columns(reference_transactable_type: "CashTransaction", reference_transactable_id: 999)
      end
      sender_transaction = create(
        :cash_transaction,
        user: other_user,
        context: other_user.main_context,
        user_bank_account: create(:user_bank_account, user: other_user, bank: create(:bank, :random))
      )

      derived_context = create(:context, user:, name: "Conversation Action Isolation", source_context: user.main_context)
      create(:context, user: other_user, scenario_key: derived_context.scenario_key)
      derived_conversation = resolve_assistant_conversation(other_user, user, scenario_key: derived_context.scenario_key)

      derived_conversation.messages.create!(
        user: other_user,
        body: "notification:create",
        headers: {
          version: "message_notification_v2",
          event: { action: "create", receiver_first_name: user.first_name, transaction_type: "CashTransaction", details: { description: "Scenario local" } },
          replay: { id: sender_transaction.id, type: "CashTransaction" }
        }.to_json
      )

      patch switch_context_path(derived_context)
      get conversation_path(derived_conversation, message_filter: "all")

      expect(response.body).to include(new_cash_transaction_path(cash_transaction: { source_message_id: derived_conversation.messages.last.id }))
      expect(response.body).not_to include(
        edit_cash_transaction_path(id: local_reference, cash_transaction: { source_message_id: derived_conversation.messages.last.id })
      )
    end

    it "keeps showing create when the latest update only matches a prior applied predecessor structurally" do
      conversation = resolve_assistant_conversation(other_user, user)
      sender_transaction = create(
        :cash_transaction,
        user: other_user,
        context: other_user.main_context,
        user_bank_account: create(:user_bank_account, user: other_user, bank: create(:bank, :random))
      )
      local_reference = create(
        :cash_transaction,
        user: user,
        context: user.main_context,
        user_bank_account: create(:user_bank_account, user:, bank: create(:bank, :random)),
        description: "Original borrow return",
        price: -20_000,
        date: Time.zone.parse("2026-03-24")
      )

      predecessor = conversation.messages.create!(
        user: other_user,
        reference_transactable: sender_transaction,
        applied_at: Time.current,
        body: "notification:update",
        headers: {
          version: "message_notification_v2",
          event: { action: "update", receiver_first_name: user.first_name, transaction_type: "CashTransaction", details: { description: "Original borrow return" } },
          replay: {
            id: sender_transaction.id,
            type: "CashTransaction",
            intent: "reimbursement",
            description: "Original borrow return",
            price: -20_000,
            date: "2026-03-24T00:00:00-03:00"
          }
        }.to_json
      )
      latest_update = conversation.messages.create!(
        user: other_user,
        reference_transactable: sender_transaction,
        body: "notification:update",
        headers: {
          version: "message_notification_v2",
          event: { action: "update", receiver_first_name: user.first_name, transaction_type: "CashTransaction", details: { description: "Updated borrow return" } },
          replay: {
            id: sender_transaction.id,
            type: "CashTransaction",
            intent: "reimbursement",
            description: "Updated borrow return",
            price: -25_000,
            date: "2026-03-25T00:00:00-03:00"
          }
        }.to_json
      )
      predecessor.update!(superseded_by: latest_update)

      get conversation_path(conversation, message_filter: "all")

      expect(response.body).to include(
        new_cash_transaction_path(cash_transaction: { source_message_id: latest_update.id })
      )
      expect(response.body).not_to include(
        edit_cash_transaction_path(id: local_reference, cash_transaction: { source_message_id: latest_update.id })
      )
      expect(response.body).to include(Message.human_attribute_name(:create))
    end

    it "renders distinct assistant message sides for my notifications and the other user's notifications" do
      conversation = resolve_assistant_conversation(user, other_user)
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

    it "shows outdated assistant message links for my notifications too" do
      conversation = resolve_assistant_conversation(user, other_user)
      outdated_message = conversation.messages.create!(
        user: user,
        body: "notification:update",
        headers: {
          version: "message_notification_v2",
          event: { action: "update", receiver_first_name: other_user.first_name, transaction_type: "CashTransaction", details: { description: "Old mine" } },
          replay: { id: 10, type: "CashTransaction" }
        }.to_json
      )
      superseding_message = conversation.messages.create!(
        user: user,
        body: "notification:update",
        headers: {
          version: "message_notification_v2",
          event: { action: "update", receiver_first_name: other_user.first_name, transaction_type: "CashTransaction", details: { description: "New mine" } },
          replay: { id: 10, type: "CashTransaction" }
        }.to_json
      )
      outdated_message.update!(superseded_by: superseding_message)

      get conversation_path(conversation, message_filter: "all")

      expect(response.body).to include(Message.human_attribute_name(:outdated_message))
      expect(response.body).to include("##{ActionView::RecordIdentifier.dom_id(superseding_message)}")
    end

    it "renders a larger sender-side show modal path for card transactions too" do
      card_transaction = create(:card_transaction, user:, context: user.main_context)
      conversation = resolve_assistant_conversation(user, other_user)
      conversation.messages.create!(
        user: user,
        body: "notification:update",
        reference_transactable: card_transaction,
        headers: {
          version: "message_notification_v2",
          event: { action: "update", receiver_first_name: other_user.first_name, transaction_type: "CardTransaction",
                   details: { description: card_transaction.description } },
          replay: { id: 1, type: "CardTransaction" }
        }.to_json
      )

      get conversation_path(conversation, message_filter: "all")

      document = Nokogiri::HTML(response.body)
      modal = document.at_css("[data-message-transaction-modal=true]")
      expect(response.body).to include(I18n.t("actions.show"), edit_card_transaction_path(card_transaction), "md:min-w-176")
      expect(modal["class"]).to include("dark:bg-slate-950", "dark:border-slate-700")
      expect(modal.at_css("[data-message-transaction-body=true]")["class"]).to include("dark:text-slate-100")
      expect(modal.css("[data-message-transaction-panel]").map { |panel| panel["class"] }).to all(include("dark:bg-slate-900/70"))
      expect(modal.css("[data-message-transaction-row]").map { |row| row["class"] }).to all(include("dark:bg-slate-950/80"))
    end

    it "labels sender-side historical show state as destroyed for destroy notifications" do
      cash_transaction = create(:cash_transaction, user:, context: user.main_context)
      conversation = resolve_assistant_conversation(user, other_user)
      conversation.messages.create!(
        user: user,
        body: "notification:destroy",
        reference_transactable: cash_transaction
      )

      get conversation_path(conversation, message_filter: "all")

      expect(response.body).to include(Message.human_attribute_name(:already_destroyed))
      expect(response.body).to include(I18n.t("actions.show"))
    end

    it "renders paid-state messages with an ok action and without the destroyed badge" do
      cash_transaction = create(:cash_transaction, user: other_user, context: other_user.main_context)
      conversation = resolve_assistant_conversation(user, other_user)
      conversation.messages.create!(
        user: other_user,
        body: "notification:paid_state",
        reference_transactable: cash_transaction,
        headers: {
          version: "message_paid_state_v1",
          event: {
            action: "paid",
            receiver_first_name: user.first_name,
            transaction_type: "CashTransaction",
            details: {
              transaction_label: "Cash transaction",
              description: "SHARED RETURN",
              installment_number: 1,
              installments_count: 1,
              date: "2026-03-26",
              paid: true
            }
          }
        }.to_json
      )

      get conversation_path(conversation, message_filter: "all")

      expect(response.body).to include(Message.human_attribute_name(:ok))
      expect(response.body).not_to include(Message.human_attribute_name(:already_destroyed))
    end

    it "allows acknowledging a paid-state message" do
      cash_transaction = create(:cash_transaction, user: other_user, context: other_user.main_context)
      conversation = resolve_assistant_conversation(user, other_user)
      message = conversation.messages.create!(
        user: other_user,
        body: "notification:paid_state",
        reference_transactable: cash_transaction,
        headers: {
          version: "message_paid_state_v1",
          event: {
            action: "paid",
            receiver_first_name: user.first_name,
            transaction_type: "CashTransaction",
            details: {
              transaction_label: "Cash transaction",
              description: "SHARED RETURN",
              installment_number: 1,
              installments_count: 1,
              date: "2026-03-26",
              paid: true
            }
          }
        }.to_json
      )

      patch apply_conversation_message_path(conversation, message), headers: turbo_stream_headers

      expect(response).to have_http_status(:ok)
      expect(message.reload.applied_at).to be_present
      expect(response.body).to include(Message.human_attribute_name(:already_acknowledged))
    end

    it "filters assistant messages by mine and theirs" do
      conversation = resolve_assistant_conversation(user, other_user)
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
      outsider = create(:user, :random)
      create(:friendship, :accepted, user: other_user, friend: outsider)
      outsider_conversation = resolve_human_conversation(other_user, outsider)

      get conversation_path(outsider_conversation)

      expect(response).to have_http_status(:not_found)
    end

    it "does not allow access to conversations from another scenario" do
      main_conversation = resolve_human_conversation(user, other_user)
      derived_context = create(:context, user:, name: "Conversation Access", source_context: user.main_context)

      patch switch_context_path(derived_context)
      get conversation_path(main_conversation)

      expect(response).to have_http_status(:not_found)
    end

    it "uses only the public conversation id and revokes non-accepted friendship access" do
      conversation = resolve_human_conversation(user, other_user)

      get "/conversations/#{conversation.id}"
      expect(response).to have_http_status(:not_found)

      %w[pending rejected blocked removed].each do |state|
        friendship.update!(state:)
        sign_in user
        get conversation_path(conversation)

        expect(response).to have_http_status(:not_found), "expected #{state} friendship access to be denied, got #{response.status} #{response.location}"
      end
    end
  end

  describe "[ participant state ]" do
    it "archives and restores only the current participant's conversation copy" do
      conversation = resolve_human_conversation(user, other_user)
      user_participant = conversation.participant_for!(user)
      other_participant = conversation.participant_for!(other_user)

      patch archive_conversation_path(conversation)

      expect(response).to redirect_to(conversations_path)
      expect(user_participant.reload).to be_archived
      expect(other_participant.reload).not_to be_archived

      get conversations_path
      expect(response.body).not_to include(conversation_path(conversation))

      sign_in other_user
      get conversations_path
      expect(response.body).to include(conversation_path(conversation))

      sign_in user
      patch unarchive_conversation_path(conversation)
      expect(user_participant.reload).not_to be_archived
      expect(response).to redirect_to(conversation_path(conversation))
    end

    it "mutes and unmutes only the current participant without hiding the conversation" do
      conversation = resolve_human_conversation(user, other_user)
      user_participant = conversation.participant_for!(user)
      other_participant = conversation.participant_for!(other_user)

      patch mute_conversation_path(conversation)

      expect(user_participant.reload).to be_muted
      expect(other_participant.reload).not_to be_muted

      get conversations_path
      expect(response.body).to include(conversation_path(conversation))

      patch unmute_conversation_path(conversation)
      expect(user_participant.reload).not_to be_muted
    end

    it "denies participant-state changes after friendship revocation" do
      conversation = resolve_human_conversation(user, other_user)
      participant = conversation.participant_for!(user)
      friendship.update!(state: "blocked")
      sign_in user

      expect do
        patch archive_conversation_path(conversation)
      end.not_to(change { participant.reload.archived_at })

      expect(response).to have_http_status(:not_found)
    end

    it "keeps read progress isolated across kinds and scenarios" do
      main_human = resolve_human_conversation(user, other_user)
      main_message = main_human.messages.create!(user: other_user, body: "Main hello")
      derived_context = create(:context, user:, name: "Cursor scenario", source_context: user.main_context)
      create(:context, user: other_user, scenario_key: derived_context.scenario_key)
      derived_assistant = resolve_assistant_conversation(other_user, user, scenario_key: derived_context.scenario_key)
      derived_message = derived_assistant.messages.create!(user: other_user, body: "Derived hello")

      get conversation_path(main_human)

      expect(main_human.participant_for!(user).reload.last_read_message).to eq(main_message)
      expect(derived_assistant.participant_for!(user).reload.last_read_message).to be_nil

      patch switch_context_path(derived_context)
      get conversation_path(derived_assistant)

      expect(derived_assistant.participant_for!(user).reload.last_read_message).to eq(derived_message)
      expect(main_human.participant_for!(user).reload.last_read_message).to eq(main_message)
    end

    it "keeps a message arriving after the visible cursor unread" do
      conversation = resolve_human_conversation(user, other_user)
      visible_message = conversation.messages.create!(user: other_user, body: "Visible")

      get conversation_path(conversation)
      arriving_message = conversation.messages.create!(user: other_user, body: "Arriving")

      participant = conversation.participant_for!(user).reload
      expect(participant.last_read_message).to eq(visible_message)
      expect(participant.unread_messages).to contain_exactly(arriving_message)
    end
  end
end
