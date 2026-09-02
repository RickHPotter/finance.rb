# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Bank-account and user-card navigation", type: :request do
  let(:user) { create(:user, :random) }
  let(:bank) { create(:bank, :random) }
  let(:card) { create(:card, :random, bank:) }

  before { sign_in user }

  it "renders account and card entry screens only as canonical HTML" do
    account = create(:user_bank_account, :random, user:, bank:)
    user_card = create(:user_card, :random, user:, card:)

    [
      user_bank_accounts_path,
      new_user_bank_account_path,
      user_bank_account_path(account),
      edit_user_bank_account_path(account),
      user_cards_path,
      new_user_card_path,
      user_card_path(user_card),
      edit_user_card_path(user_card)
    ].each do |path|
      get path, headers: html_headers

      expect(response).to have_http_status(:success)
      expect(response.media_type).to eq(Mime[:html].to_s)
      expect(response.body).not_to include("<turbo-stream")
    end
  end

  it "canonicalizes obsolete stream-format entry URLs" do
    account = create(:user_bank_account, :random, user:, bank:)
    user_card = create(:user_card, :random, user:, card:)

    {
      user_bank_accounts_path(format: :turbo_stream) => user_bank_accounts_path,
      new_user_bank_account_path(format: :turbo_stream) => new_user_bank_account_path,
      user_bank_account_path(account, format: :turbo_stream) => user_bank_account_path(account),
      edit_user_bank_account_path(account, format: :turbo_stream) => edit_user_bank_account_path(account),
      user_cards_path(format: :turbo_stream) => user_cards_path,
      new_user_card_path(format: :turbo_stream) => new_user_card_path,
      user_card_path(user_card, format: :turbo_stream) => user_card_path(user_card),
      edit_user_card_path(user_card, format: :turbo_stream) => edit_user_card_path(user_card)
    }.each do |stream_path, canonical_path|
      get stream_path

      expect(response).to have_http_status(:moved_permanently)
      expect(response).to redirect_to(canonical_path)
    end
  end

  it "marks visible save submitters for top-level replacement while leaving hidden updates local" do
    [ new_user_bank_account_path, new_user_card_path ].each do |path|
      get path
      document = Nokogiri::HTML.parse(response.body)
      visible_submitter = document.at_css("form button[type='submit'][data-turbo-frame='_top'][data-turbo-action='replace']")
      hidden_update = document.css("form input[type='submit']").find { |input| input["value"] == "Update" }

      expect(visible_submitter).to be_present
      expect(hidden_update).to be_present
      expect(hidden_update["data-turbo-frame"]).to be_nil
      expect(hidden_update["data-turbo-action"]).to be_nil
    end
  end

  it "carries filtered index state through row links and edit actions without a redundant list action" do
    account = create(:user_bank_account, :random, user:, bank:)
    user_card = create(:user_card, :random, user:, card:)
    account_return = canonical_account_return(account)
    card_return = canonical_card_return(user_card)

    get account_return
    account_document = Nokogiri::HTML.parse(response.body)
    account_show_path = user_bank_account_path(account, return_to: account_return)
    expect(account_document.at_css(%[a[href="#{account_show_path}"]])).to be_present

    get account_show_path
    account_show_document = Nokogiri::HTML.parse(response.body)
    expect(account_show_document.at_css(%[a[href="#{account_return}"]])).to be_nil
    expect(account_show_document.at_css(%[a[href="#{edit_user_bank_account_path(account, return_to: account_return)}"]])).to be_present

    get card_return
    card_document = Nokogiri::HTML.parse(response.body)
    card_show_path = user_card_path(user_card, return_to: card_return)
    expect(card_document.at_css(%[a[href="#{card_show_path}"]])).to be_present

    get card_show_path
    card_show_document = Nokogiri::HTML.parse(response.body)
    expect(card_show_document.at_css(%[a[href="#{card_return}"]])).to be_nil
    expect(card_show_document.at_css(%[a[href="#{edit_user_card_path(user_card, return_to: card_return)}"]])).to be_present
  end

  it "redirects successful active creates to refreshable seeded transaction URLs" do
    post user_bank_accounts_path, params: {
      user_bank_account: account_params(user_bank_account_name: "CANONICAL ACCOUNT", active: true)
    }, headers: turbo_stream_headers

    account = user.user_bank_accounts.find_by!(user_bank_account_name: "CANONICAL ACCOUNT")
    account_destination = new_cash_transaction_path(user_bank_account_id: account.id)

    expect(response).to have_http_status(:see_other)
    expect(response).to redirect_to(account_destination)

    get account_destination
    expect(response).to have_http_status(:success)
    expect(response.body).to include("CANONICAL ACCOUNT")

    post user_cards_path, params: {
      user_card: user_card_params(user_card_name: "CANONICAL CARD", active: true)
    }, headers: turbo_stream_headers

    user_card = user.user_cards.find_by!(user_card_name: "CANONICAL CARD")
    card_destination = new_card_transaction_path(user_card_id: user_card.id)

    expect(response).to have_http_status(:see_other)
    expect(response).to redirect_to(card_destination)

    get card_destination
    expect(response).to have_http_status(:success)
    expect(response.body).to include("CANONICAL CARD")
  end

  it "redirects successful active updates to refreshable seeded transaction URLs" do
    account = create(:user_bank_account, :random, user:, bank:)
    user_card = create(:user_card, :random, user:, card:)

    patch user_bank_account_path(account), params: {
      user_bank_account: account_params(user_bank_account_name: "UPDATED ACCOUNT", active: true)
    }, headers: turbo_stream_headers

    expect(response).to have_http_status(:see_other)
    expect(response).to redirect_to(new_cash_transaction_path(user_bank_account_id: account.id))

    patch user_card_path(user_card), params: {
      user_card: user_card_params(user_card_name: "UPDATED CARD", active: true)
    }, headers: turbo_stream_headers

    expect(response).to have_http_status(:see_other)
    expect(response).to redirect_to(new_card_transaction_path(user_card_id: user_card.id))
  end

  it "keeps Turbo validation failures bounded to the submitted form" do
    [
      [
        user_bank_accounts_path,
        { user_bank_account: account_params(user_bank_account_name: "", active: true) },
        "new_user_bank_account"
      ],
      [
        user_cards_path,
        { user_card: user_card_params(user_card_name: "INVALID CARD", credit_limit: "", active: true) },
        "new_user_card"
      ]
    ].each do |path, request_params, target|
      post path, params: request_params, headers: turbo_stream_headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.media_type).to eq(Mime[:turbo_stream].to_s)
      expect(response.body).to include(%[target="#{target}"])
      expect(response.body).not_to include(%[target="center_container"])
    end
  end

  it "renders non-Turbo validation failures at the canonical form URL" do
    post user_bank_accounts_path, params: {
      user_bank_account: account_params(user_bank_account_name: "", active: true)
    }, headers: html_headers

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.media_type).to eq(Mime[:html].to_s)
    expect(response.location).to be_nil
    expect(response.body).not_to include("<turbo-stream")

    post user_cards_path, params: {
      user_card: user_card_params(user_card_name: "INVALID CARD", credit_limit: "", active: true)
    }, headers: html_headers

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.media_type).to eq(Mime[:html].to_s)
    expect(response.location).to be_nil
    expect(response.body).not_to include("<turbo-stream")
  end

  it "uses the same canonical redirect destinations for successful non-Turbo saves" do
    account_return = user_bank_accounts_path(search_term: "inactive")
    card_return = user_cards_path(search_term: "inactive")

    post user_bank_accounts_path, params: {
      return_to: account_return,
      user_bank_account: account_params(user_bank_account_name: "INACTIVE ACCOUNT", active: false)
    }, headers: html_headers

    expect(response).to have_http_status(:see_other)
    expect(response).to redirect_to(account_return)

    post user_cards_path, params: {
      return_to: card_return,
      user_card: user_card_params(user_card_name: "INACTIVE CARD", active: false)
    }, headers: html_headers

    expect(response).to have_http_status(:see_other)
    expect(response).to redirect_to(card_return)
  end

  it "redirects guarded destroys to the validated filtered index state" do
    account = create(:user_bank_account, :random, user:, bank:)
    user_card = create(:user_card, :random, user:, card:)
    create(:cash_transaction, user:, context: user.main_context, user_bank_account: account)
    create(:card_transaction, user:, context: user.main_context, user_card:)

    account_return = Navigation::UserBankAccounts.new(
      raw: user_bank_accounts_path(search_term: account.user_bank_account_name, user_bank_account: { status: [ "active" ] }),
      fallback: user_bank_accounts_path,
      current_user: user
    ).destination
    card_return = Navigation::UserCards.new(
      raw: user_cards_path(search_term: user_card.user_card_name, user_card: { status: [ "active" ] }),
      fallback: user_cards_path,
      current_user: user
    ).destination

    expect do
      delete user_bank_account_path(account), params: { return_to: account_return }, headers: turbo_stream_headers
    end.not_to change(UserBankAccount, :count)
    expect(response).to have_http_status(:see_other)
    expect(response).to redirect_to(account_return)

    expect do
      delete user_card_path(user_card), params: { return_to: card_return }, headers: turbo_stream_headers
    end.not_to change(UserCard, :count)
    expect(response).to have_http_status(:see_other)
    expect(response).to redirect_to(card_return)
  end

  private

  def account_params(overrides = {})
    {
      user_bank_account_name: "ACCOUNT",
      agency_number: "1234",
      account_number: "987654",
      balance: 50_000,
      active: true,
      bank_id: bank.id,
      user_id: user.id
    }.merge(overrides)
  end

  def user_card_params(overrides = {})
    {
      user_card_name: "CARD",
      due_date_day: 10,
      days_until_due_date: 7,
      min_spend: 10_000,
      credit_limit: 200_000,
      active: true,
      card_id: card.id,
      user_id: user.id
    }.merge(overrides)
  end

  def canonical_account_return(account)
    Navigation::UserBankAccounts.new(
      raw: user_bank_accounts_path(search_term: account.user_bank_account_name, user_bank_account: { status: [ "active" ] }),
      fallback: user_bank_accounts_path,
      current_user: user
    ).destination
  end

  def canonical_card_return(user_card)
    Navigation::UserCards.new(
      raw: user_cards_path(search_term: user_card.user_card_name, user_card: { status: [ "active" ] }),
      fallback: user_cards_path,
      current_user: user
    ).destination
  end
end
