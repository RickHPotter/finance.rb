# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Conversation and internal-screen Turbo navigation", type: :feature do
  let(:user) { create(:user, first_name: "Rikki", last_name: "Potter", email: "rikki-browser-navigation@example.com") }
  let(:other_user) { create(:user, :random) }
  let!(:friendship) { create(:friendship, :accepted, user:, friend: other_user) }

  before { sign_in user }

  it "selects and updates a conversation without letting realtime streams change its URL" do
    conversation = resolve_human_conversation(user, other_user)
    conversation.messages.create!(user: other_user, body: "Hello from history")
    index_path = conversations_path(filter: "human")

    visit index_path
    find("a[href='#{conversation_path(conversation)}']", match: :first).click

    expect_browser_path(conversation_path(conversation))
    refresh_browser_at(conversation_path(conversation))

    fill_in "message_body", with: "Realtime browser message"
    find("form#messages_conversation_#{conversation.id} input[type='submit']", match: :first).click

    expect_browser_path(conversation_path(conversation))
    expect(page).to have_text("Realtime browser message")
    browser_back_to(index_path)
    browser_forward_to(conversation_path(conversation))
    refresh_browser_at(conversation_path(conversation))
  end

  it "opens an actionable message at the canonical transaction form URL" do
    remote_transaction = create(:cash_transaction, user: other_user, context: other_user.main_context)
    conversation = resolve_assistant_conversation(other_user, user)
    message = conversation.messages.create!(
      user: other_user,
      body: "notification:create",
      headers: {
        version: "message_notification_v2",
        event: {
          action: "create",
          receiver_first_name: user.first_name,
          transaction_type: "CashTransaction",
          details: { description: "Browser action" }
        },
        replay: { id: remote_transaction.id, type: "CashTransaction" }
      }.to_json
    )
    conversation_path_with_state = conversation_path(conversation, message_filter: "all")
    return_to = conversation_path(conversation, message_filter: "all", message_side: %w[mine theirs])
    action_path = new_cash_transaction_path(cash_transaction: { source_message_id: message.id }, return_to:)

    visit conversation_path_with_state
    find("a[href='#{action_path}']", match: :first).click

    expect_browser_path(action_path)
    refresh_browser_at(action_path)
    browser_back_to(conversation_path_with_state)
  end

  it "keeps internal ledger scope and filter state in the refreshable URL" do
    create(:entity, user:, entity_name: "LALA")
    initial_path = internal_cash_transactions_path(
      entity_slug: "lala",
      active_month_years: [ 202_607 ].to_json
    )

    visit initial_path
    fill_in "search_term", with: "SCOPED FILTER"

    expect(page).to have_field("search_term", with: "SCOPED FILTER")
    expect(page).to have_current_path(/search_term=SCOPED(?:\+|%20)FILTER/)

    current_uri = URI.parse(page.current_url)
    query = Rack::Utils.parse_nested_query(current_uri.query)
    expect(current_uri.path).to eq(internal_cash_transactions_path(entity_slug: "lala"))
    expect(query).to include("search_term" => "SCOPED FILTER", "active_month_years" => [ 202_607 ].to_json)

    refresh_browser_at(current_uri.request_uri)
    lazy_frame = find("turbo-frame#month_year_container_202607", visible: :all)
    expect(URI.parse(lazy_frame["src"]).path).to eq(month_year_internal_cash_transactions_path(entity_slug: "lala"))
  end
end
