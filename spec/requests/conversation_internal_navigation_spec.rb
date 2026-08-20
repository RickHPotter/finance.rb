# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Conversation and internal-screen navigation", type: :request do
  let(:user) { create(:user, first_name: "Rikki", last_name: "Potter", email: "rikki-navigation@example.com") }
  let(:other_user) { create(:user, :random) }
  let!(:friendship) { create(:friendship, :accepted, user:, friend: other_user) }
  let(:conversation) { Conversation.find_or_create_human_between!(user, other_user) }

  before { sign_in user }

  it "renders conversation and scoped internal entries as canonical HTML" do
    create(:entity, user:, entity_name: "LALA")

    [
      conversations_path,
      conversation_path(conversation),
      internal_cash_transactions_path(entity_slug: "lala"),
      internal_card_transactions_path(entity_slug: "lala")
    ].each do |path|
      get path, headers: html_headers

      expect(response).to have_http_status(:success)
      expect(response.media_type).to eq(Mime[:html].to_s)
      expect(response.body).to include(%[turbo-frame id="center_container"])
      expect(response.body).not_to include("<turbo-stream")
    end
  end

  it "canonicalizes obsolete stream-format conversation and internal entry URLs" do
    create(:entity, user:, entity_name: "LALA")

    {
      conversations_path(format: :turbo_stream) => conversations_path,
      conversation_path(conversation, format: :turbo_stream) => conversation_path(conversation),
      internal_cash_transactions_path(entity_slug: "lala", format: :turbo_stream) => internal_cash_transactions_path(entity_slug: "lala"),
      internal_card_transactions_path(entity_slug: "lala", format: :turbo_stream) => internal_card_transactions_path(entity_slug: "lala")
    }.each do |stream_path, canonical_path|
      get stream_path

      expect(response).to have_http_status(:moved_permanently)
      expect(response).to redirect_to(canonical_path)
    end
  end

  it "uses top-level advances for conversation selection and actionable transaction entry" do
    remote_transaction = create(:cash_transaction, user: other_user, context: other_user.main_context)
    assistant_conversation = Conversation.find_or_create_assistant_between!(other_user, user)
    message = assistant_conversation.messages.create!(
      user: other_user,
      body: "notification:create",
      headers: {
        version: "message_notification_v2",
        event: {
          action: "create",
          receiver_first_name: user.first_name,
          transaction_type: "CashTransaction",
          details: { description: "Canonical action" }
        },
        replay: { id: remote_transaction.id, type: "CashTransaction" }
      }.to_json
    )

    get conversations_path(filter: "assistant")
    document = Nokogiri::HTML(response.body)
    expect_top_level_advance(document.at_css("a[href='#{conversation_path(assistant_conversation)}']"))

    get conversation_path(assistant_conversation, message_filter: "all")
    document = Nokogiri::HTML(response.body)
    action_path = new_cash_transaction_path(cash_transaction: { source_message_id: message.id })
    expect_top_level_advance(document.at_css("a[href='#{action_path}']"))
    expect(response.body).not_to include("format=turbo_stream")
  end

  it "keeps message creation and acknowledgement as local streams" do
    message = conversation.messages.create!(user: other_user, body: "Existing message")

    post conversation_messages_path(conversation), params: { message: { body: "Realtime message" } }, headers: turbo_stream_headers

    expect(response).to have_http_status(:success)
    expect(response.media_type).to eq(Mime[:turbo_stream].to_s)
    expect(response.body).to include("<turbo-stream")
    expect(response.body).not_to include(%[target="center_container"])

    patch apply_conversation_message_path(conversation, message), headers: turbo_stream_headers

    expect(response).to have_http_status(:success)
    expect(response.media_type).to eq(Mime[:turbo_stream].to_s)
    expect(response.body).to include("<turbo-stream")
    expect(response.body).not_to include(%[target="center_container"])
  end

  it "retains internal and external route scope in filters and lazy month URLs" do
    create(:entity, user:, entity_name: "LALA")
    active_months = [ 202_607 ].to_json

    get internal_cash_transactions_path(
      entity_slug: "lala",
      search_term: "scoped",
      active_month_years: active_months
    )

    document = Nokogiri::HTML(response.body)
    form = document.at_css("form#search_form")
    lazy_frame = document.at_css("turbo-frame#month_year_container_202607")
    expect(form["action"]).to eq(internal_cash_transactions_path(entity_slug: "lala"))
    expect(form["data-turbo-frame"]).to eq("_top")
    expect(form["data-turbo-action"]).to eq("replace")
    expect_scoped_path(lazy_frame["src"], month_year_internal_cash_transactions_path(entity_slug: "lala"))

    get internal_card_transactions_path(
      entity_slug: "lala",
      search_term: "scoped",
      active_month_years: active_months
    )

    document = Nokogiri::HTML(response.body)
    form = document.at_css("form#search_form")
    lazy_frame = document.at_css("turbo-frame#month_year_container_202607")
    expect(form["action"]).to eq(internal_card_transactions_path(entity_slug: "lala"))
    expect(form["data-turbo-frame"]).to eq("_top")
    expect(form["data-turbo-action"]).to eq("replace")
    expect_scoped_path(lazy_frame["src"], month_year_internal_card_transactions_path(entity_slug: "lala"))

    get external_cash_transactions_path(
      user_slug: "rikki",
      entity_slug: "lala",
      search_term: "scoped",
      active_month_years: active_months
    )

    document = Nokogiri::HTML(response.body)
    form = document.at_css("form#search_form")
    lazy_frame = document.at_css("turbo-frame#month_year_container_202607")
    expect(form["action"]).to eq(external_cash_transactions_path(user_slug: "rikki", entity_slug: "lala"))
    expect(form["data-turbo-frame"]).to eq("_top")
    expect(form["data-turbo-action"]).to eq("replace")
    expect_scoped_path(lazy_frame["src"], month_year_external_cash_transactions_path(user_slug: "rikki", entity_slug: "lala"))

    get external_card_transactions_path(
      user_slug: "rikki",
      entity_slug: "lala",
      search_term: "scoped",
      active_month_years: active_months
    )

    document = Nokogiri::HTML(response.body)
    form = document.at_css("form#search_form")
    lazy_frame = document.at_css("turbo-frame#month_year_container_202607")
    expect(form["action"]).to eq(external_card_transactions_path(user_slug: "rikki", entity_slug: "lala"))
    expect(form["data-turbo-frame"]).to eq("_top")
    expect(form["data-turbo-action"]).to eq("replace")
    expect_scoped_path(lazy_frame["src"], month_year_external_card_transactions_path(user_slug: "rikki", entity_slug: "lala"))
  end

  private

  def expect_top_level_advance(node)
    expect(node).to be_present
    expect(node["data-turbo-frame"]).to eq("_top")
    expect(node["data-turbo-action"]).to eq("advance")
  end

  def expect_scoped_path(raw_path, expected_path)
    uri = URI.parse(raw_path)

    expect(uri.path).to eq(expected_path)
    expect(Rack::Utils.parse_nested_query(uri.query)).to include("search_term" => "scoped")
  end
end
