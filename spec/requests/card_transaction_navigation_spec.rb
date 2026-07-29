# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Card transaction navigation", type: :request do
  let(:user) { create(:user, :random) }
  let(:user_card) { create(:user_card, :random, user:) }
  let(:category) { create(:category, :random, user:) }
  let(:entity) { create(:entity, :random, user:) }
  let(:transaction_date) { 1.month.from_now.to_date }
  let(:card_transaction_payload) do
    Params::CardTransactions.new(
      card_transaction: {
        description: "Canonical card navigation",
        price: -12_345,
        date: transaction_date,
        month: transaction_date.month,
        year: transaction_date.year,
        user_id: user.id,
        user_card_id: user_card.id
      },
      card_installments: { count: 1 },
      category_transactions: [ { category_id: category.id } ],
      entity_transactions: [
        {
          entity_id: entity.id,
          price: 0,
          price_to_be_returned: 0,
          exchanges_attributes: []
        }
      ]
    )
  end
  let(:transaction_params) { card_transaction_payload.params }

  before { sign_in user }

  context "with a Turbo workflow-finishing create" do
    subject(:perform_request) { post card_transactions_path, params: transaction_params, headers: turbo_stream_headers }

    let(:expected_destination) { card_transactions_path(user_card_id: user_card.id) }

    it_behaves_like "a canonical top-level mutation redirect"
  end

  context "with a non-Turbo create" do
    subject(:perform_request) { post card_transactions_path, params: transaction_params, headers: html_headers }

    let(:expected_destination) { card_transactions_path(user_card_id: user_card.id) }

    it_behaves_like "a canonical top-level mutation redirect"
  end

  context "with a Turbo validation failure" do
    subject(:perform_request) do
      post card_transactions_path,
           params: transaction_params.deep_merge(card_transaction: { description: "" }),
           headers: turbo_stream_headers
    end

    let(:expected_form_marker) { 'target="new_card_transaction"' }

    it_behaves_like "a canonical top-level validation failure"

    it "updates only notifications and the transaction form boundary" do
      perform_request

      expect(response.body).to include('target="notification"', 'target="new_card_transaction"')
      expect(response.body).not_to include('target="center_container"')
    end
  end

  context "with a non-Turbo validation failure" do
    subject(:perform_request) do
      post card_transactions_path,
           params: transaction_params.deep_merge(card_transaction: { description: "" }),
           headers: html_headers
    end

    let(:expected_form_marker) { 'id="new_card_transaction"' }

    it_behaves_like "a canonical top-level validation failure"
  end

  it "renders top-level card GET screens only as canonical HTML" do
    transaction = create(:card_transaction, user:, context: user.main_context, user_card:)

    [
      card_transactions_path,
      search_card_transactions_path,
      new_card_transaction_path,
      card_transaction_path(transaction),
      edit_card_transaction_path(transaction),
      duplicate_card_transaction_path(transaction)
    ].each do |path|
      get path, headers: html_headers

      expect(response).to have_http_status(:success)
      expect(response.media_type).to eq(Mime[:html].to_s)
      expect(response.body).not_to include("<turbo-stream")
    end
  end

  it "canonicalizes obsolete stream-format entry to top-level card screens" do
    transaction = create(:card_transaction, user:, context: user.main_context, user_card:)

    {
      card_transactions_path(format: :turbo_stream) => card_transactions_path,
      new_card_transaction_path(format: :turbo_stream) => new_card_transaction_path,
      edit_card_transaction_path(transaction, format: :turbo_stream) => edit_card_transaction_path(transaction)
    }.each do |stream_path, canonical_path|
      get stream_path

      expect(response).to have_http_status(:moved_permanently)
      expect(response).to redirect_to(canonical_path)
    end
  end

  it "marks workflow-finishing submitters for top-level replacement and leaves reactive Update local" do
    get new_card_transaction_path(user_card_id: user_card.id)

    document = Nokogiri::HTML.parse(response.body)
    finishing_submitters = document.css("#transaction_form [type='submit'][data-turbo-frame='_top'][data-turbo-action='replace']")
    reactive_submitter = document.at_css("#transaction_form [data-reactive-form-target='updateButton']")

    expect(finishing_submitters.size).to eq(3)
    expect(reactive_submitter).to be_present
    expect(reactive_submitter["data-turbo-frame"]).to be_nil
    expect(reactive_submitter["data-turbo-action"]).to be_nil
  end

  it "restores selected card and invoice state after create" do
    active_month_year = transaction_date.strftime("%Y%m").to_i
    return_to = card_transactions_path(
      user_card_id: user_card.id,
      default_year: transaction_date.year,
      active_month_years: [ active_month_year ].to_json,
      sort: "description",
      direction: "desc"
    )
    expected_destination = Navigation::CardTransactions.new(
      raw: return_to,
      fallback: card_transactions_path,
      current_user: user,
      current_context: user.main_context
    ).destination

    post card_transactions_path,
         params: transaction_params.merge(return_to:),
         headers: turbo_stream_headers

    expect(response).to have_http_status(:see_other)
    expect(response).to redirect_to(expected_destination)
  end

  it "keeps hidden billing-reference refresh submissions in place" do
    post card_transactions_path,
         params: transaction_params.merge(commit: "Update"),
         headers: turbo_stream_headers

    expect(response).to have_http_status(:ok)
    expect(response).not_to be_redirect
    expect(response.body).to include('target="new_card_transaction"')
    expect(response.body).not_to include('target="center_container"')
  end
end
