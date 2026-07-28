# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Cash transaction navigation", type: :request do
  let(:user) { create(:user, :random) }
  let(:bank_account) { create(:user_bank_account, :random, user:) }
  let(:category) { create(:category, :random, user:) }
  let(:entity) { create(:entity, :random, user:) }
  let(:transaction_date) { 1.month.from_now.to_date }
  let(:cash_transaction_payload) do
    Params::CashTransactions.new(
      cash_transaction: {
        description: "Canonical cash navigation",
        price: 12_345,
        date: transaction_date,
        month: transaction_date.month,
        year: transaction_date.year,
        user_id: user.id,
        user_bank_account_id: bank_account.id
      },
      cash_installments: { count: 1 },
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
  let(:transaction_params) { cash_transaction_payload.params }

  before { sign_in user }

  context "with a Turbo workflow-finishing create" do
    subject(:perform_request) { post cash_transactions_path, params: transaction_params, headers: turbo_stream_headers }

    let(:expected_destination) { cash_transactions_path }

    it_behaves_like "a canonical top-level mutation redirect"
  end

  context "with a non-Turbo create" do
    subject(:perform_request) { post cash_transactions_path, params: transaction_params, headers: html_headers }

    let(:expected_destination) { cash_transactions_path }

    it_behaves_like "a canonical top-level mutation redirect"
  end

  context "with a Turbo validation failure" do
    subject(:perform_request) do
      post cash_transactions_path,
           params: transaction_params.deep_merge(cash_transaction: { description: "" }),
           headers: turbo_stream_headers
    end

    let(:expected_form_marker) { 'target="new_cash_transaction"' }

    it_behaves_like "a canonical top-level validation failure"

    it "updates only notifications and the transaction form boundary" do
      perform_request

      expect(response.body).to include('target="notification"', 'target="new_cash_transaction"')
      expect(response.body).not_to include('target="center_container"')
    end
  end

  context "with a non-Turbo validation failure" do
    subject(:perform_request) do
      post cash_transactions_path,
           params: transaction_params.deep_merge(cash_transaction: { description: "" }),
           headers: html_headers
    end

    let(:expected_form_marker) { 'id="new_cash_transaction"' }

    it_behaves_like "a canonical top-level validation failure"
  end

  it "renders top-level cash GET screens only as canonical HTML" do
    transaction = create(:cash_transaction, user:, context: user.main_context, user_bank_account: bank_account)

    [
      cash_transactions_path,
      new_cash_transaction_path,
      cash_transaction_path(transaction),
      edit_cash_transaction_path(transaction),
      duplicate_cash_transaction_path(transaction)
    ].each do |path|
      get path, headers: html_headers

      expect(response).to have_http_status(:success)
      expect(response.media_type).to eq(Mime[:html].to_s)
      expect(response.body).not_to include("<turbo-stream")
    end
  end

  it "canonicalizes obsolete stream-format entry to top-level cash screens" do
    transaction = create(:cash_transaction, user:, context: user.main_context, user_bank_account: bank_account)

    {
      cash_transactions_path(format: :turbo_stream) => cash_transactions_path,
      new_cash_transaction_path(format: :turbo_stream) => new_cash_transaction_path,
      edit_cash_transaction_path(transaction, format: :turbo_stream) => edit_cash_transaction_path(transaction)
    }.each do |stream_path, canonical_path|
      get stream_path

      expect(response).to have_http_status(:moved_permanently)
      expect(response).to redirect_to(canonical_path)
    end
  end

  it "marks workflow-finishing submitters for top-level replacement and leaves reactive Update local" do
    get new_cash_transaction_path

    document = Nokogiri::HTML.parse(response.body)
    finishing_submitters = document.css("#transaction_form [type='submit'][data-turbo-frame='_top'][data-turbo-action='replace']")
    reactive_submitter = document.at_css("#transaction_form [data-reactive-form-target='updateButton']")

    expect(finishing_submitters.size).to eq(3)
    expect(reactive_submitter).to be_present
    expect(reactive_submitter["data-turbo-frame"]).to be_nil
    expect(reactive_submitter["data-turbo-action"]).to be_nil
  end

  it "keeps the default New URL clean and carries only meaningful filtered return state" do
    get cash_transactions_path
    default_new_link = Nokogiri::HTML.parse(response.body).at_css("#new_cash_transaction")

    expect(default_new_link["href"]).to eq(new_cash_transaction_path)

    get cash_transactions_path(search_term: "rent", sort: "description", direction: "desc")
    filtered_new_link = Nokogiri::HTML.parse(response.body).at_css("#new_cash_transaction")
    return_to = Rack::Utils.parse_nested_query(URI.parse(filtered_new_link["href"]).query).fetch("return_to")

    expect(return_to).to eq("/cash_transactions?direction=desc&search_term=rent&sort=description")
  end

  it "redirects create to validated filtered index state" do
    return_to = cash_transactions_path(
      active_month_years: [ Time.zone.today.strftime("%Y%m").to_i ].to_json,
      sort: "description",
      direction: "desc",
      cash_transaction: { user_bank_account_id: [ bank_account.id ] }
    )
    expected_destination = Navigation::CashTransactions.new(
      raw: return_to,
      fallback: cash_transactions_path,
      current_user: user,
      current_context: user.main_context
    ).destination

    post cash_transactions_path,
         params: transaction_params.merge(return_to:),
         headers: turbo_stream_headers

    expect(response).to have_http_status(:see_other)
    expect(response).to redirect_to(expected_destination)
  end

  it "falls back when return state contains a foreign account" do
    foreign_user = create(:user, :random)
    foreign_account = create(:user_bank_account, :random, user: foreign_user)
    unsafe_return_to = cash_transactions_path(cash_transaction: { user_bank_account_id: foreign_account.id })

    post cash_transactions_path,
         params: transaction_params.merge(return_to: unsafe_return_to),
         headers: turbo_stream_headers

    expect(response).to have_http_status(:see_other)
    expect(response).to redirect_to(cash_transactions_path)
  end

  it "keeps hidden recalculation submissions in place" do
    post cash_transactions_path,
         params: transaction_params.merge(commit: "Update", return_to: cash_transactions_path),
         headers: turbo_stream_headers

    expect(response).to have_http_status(:ok)
    expect(response.location).to be_nil
    expect(response.body).to include('action="update" target="new_cash_transaction"')
    expect(response.body).not_to include('target="center_container"')
  end

  it "redirects successful update and destroy to the canonical return destination" do
    post cash_transactions_path, params: transaction_params, headers: turbo_stream_headers
    transaction = CashTransaction.order(:id).last
    cash_transaction_payload.use_base(
      transaction,
      cash_transaction_options: { description: "Canonical cash navigation updated" }
    )

    put cash_transaction_path(transaction),
        params: cash_transaction_payload.params.merge(return_to: cash_transactions_path),
        headers: turbo_stream_headers

    expect(response).to have_http_status(:see_other)
    expect(response).to redirect_to(cash_transactions_path)

    delete cash_transaction_path(transaction, return_to: cash_transactions_path),
           headers: turbo_stream_headers

    expect(response).to have_http_status(:see_other)
    expect(response).to redirect_to(cash_transactions_path)
  end

  it "uses the same update destination and validation status without Turbo" do
    post cash_transactions_path, params: transaction_params, headers: turbo_stream_headers
    transaction = CashTransaction.order(:id).last
    cash_transaction_payload.use_base(
      transaction,
      cash_transaction_options: { description: "" }
    )

    put cash_transaction_path(transaction),
        params: cash_transaction_payload.params,
        headers: html_headers

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.location).to be_nil
    expect(response.body).to include(%[id="cash_transaction_#{transaction.id}"])

    cash_transaction_payload.use_base(
      transaction.reload,
      cash_transaction_options: { description: "Non-Turbo canonical update" }
    )
    put cash_transaction_path(transaction),
        params: cash_transaction_payload.params,
        headers: html_headers

    expect(response).to have_http_status(:see_other)
    expect(response).to redirect_to(cash_transactions_path)
  end

  it "continues a duplicate chain at a refreshable owned duplicate URL" do
    post cash_transactions_path,
         params: transaction_params.merge(chain_mode: "duplicate", continue_chain: "1"),
         headers: turbo_stream_headers

    created_transaction = CashTransaction.order(:id).last
    location = URI.parse(response.location)
    continuation_state = Rack::Utils.parse_nested_query(location.query)

    expect(response).to have_http_status(:see_other)
    expect(location.path).to eq(duplicate_cash_transaction_path(created_transaction))
    expect(continuation_state.fetch("chain_mode")).to eq("duplicate")
    expect(continuation_state.fetch("chain_record_ids")).to eq([ created_transaction.id.to_s ])
    expect(continuation_state.fetch("continue_chain")).to eq("1")

    follow_redirect!(headers: html_headers)

    expect(response).to have_http_status(:success)
    expect(response.media_type).to eq(Mime[:html].to_s)
    chain_record_input = Nokogiri::HTML.parse(response.body).at_css('input[name="chain_record_ids[]"]')
    expect(chain_record_input["value"]).to eq(created_transaction.id.to_s)
  end

  it "keeps a guarded destroy local and makes its confirmation a replacing top-level submit" do
    transaction = create(
      :cash_transaction,
      user:,
      context: user.main_context,
      user_bank_account: bank_account,
      date: 2.months.ago,
      month: 2.months.ago.month,
      year: 2.months.ago.year
    )
    transaction.cash_installments.first.update_columns(paid: true)

    delete cash_transaction_path(transaction), headers: turbo_stream_headers

    document = Nokogiri::HTML.fragment(response.body)
    confirmation_form = document.at_css("form[data-turbo-frame='_top'][data-turbo-action='replace']")

    expect(response).to have_http_status(:unprocessable_content)
    expect(confirmation_form).to be_present
    expect(confirmation_form["data-turbo-stream"]).to eq("true")
  end

  it "rejects foreign chain records and duplicate sources" do
    foreign_user = create(:user, :random)
    foreign_transaction = create(:cash_transaction, user: foreign_user, context: foreign_user.main_context)

    get new_cash_transaction_path(chain_record_ids: [ foreign_transaction.id ], continue_chain: "1")

    expect(response).to have_http_status(:success)
    expect(response.body).not_to include(%(name="chain_record_ids[]" value="#{foreign_transaction.id}"))

    get duplicate_cash_transaction_path(foreign_transaction)

    expect(response).to have_http_status(:not_found)
  end
end
