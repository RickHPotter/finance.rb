# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Canonical ledger navigation", type: :request do
  let(:owner) { create(:user, :random) }
  let(:entity) { create(:entity, user: owner, entity_name: "CRÍSTIAN PENS") }
  let(:context) { owner.main_context }
  let(:share) { Ledgers::Shares::Create.call(entity:, context:) }
  let(:active_months) { [ 202_609 ].to_json }

  it "canonicalizes root and search entries without dropping bounded query state" do
    sign_in owner
    get internal_root_path(entity_public_id: entity.public_id), params: navigation_params

    expect_canonical_redirect(internal_cash_transactions_path(entity_public_id: entity.public_id), search_term: "ledger search")

    get search_internal_card_transactions_path(entity_public_id: entity.public_id), params: navigation_params

    expect_canonical_redirect(internal_card_transactions_path(entity_public_id: entity.public_id), search_term: "ledger search")

    get external_root_path(share_token: share.token), params: navigation_params

    expect_canonical_redirect(external_cash_transactions_path(share_token: share.token), search_term: "ledger search")

    get search_external_card_transactions_path(share_token: share.token), params: navigation_params

    expect_canonical_redirect(external_card_transactions_path(share_token: share.token), search_term: "ledger search")
  end

  it "upgrades one unambiguous owned legacy slug and rejects ambiguous or foreign matches" do
    sign_in owner
    entity

    get "/internal/cristian-pens/cash_transactions", params: navigation_params
    expect_canonical_redirect(internal_cash_transactions_path(entity_public_id: entity.public_id), search_term: "ledger search")

    get "/internal/cristian-pens/cash_transactions/month_year", params: navigation_params.merge(month_year: 202_609)
    expect_canonical_redirect(month_year_internal_cash_transactions_path(entity_public_id: entity.public_id), month_year: "202609")

    create(:entity, user: owner, entity_name: "CRISTIAN PENS")
    get "/internal/cristian-pens/cash_transactions"
    expect(response).to have_http_status(:not_found)

    foreign = create(:entity, user: create(:user, :random), entity_name: "FOREIGN LEDGER")
    get "/internal/#{foreign.entity_name.parameterize}/cash_transactions"
    expect(response).to have_http_status(:not_found)
  end

  it "keeps legacy external slugs unavailable without a capability and redirects only through a valid share" do
    old_path = "/old-owner/external/old-entity/card_transactions/search"

    get old_path, params: navigation_params
    expect(response).to have_http_status(:not_found)

    get old_path, params: navigation_params.merge(share_token: "invalid")
    expect(response).to have_http_status(:not_found)

    get old_path, params: navigation_params.merge(share_token: share.token, card_transaction: { user_card_id: 999_999 })
    expect_canonical_redirect(external_card_transactions_path(share_token: share.token), search_term: "ledger search")
    expect(redirect_query).not_to include("card_transaction")
    expect(response.location).not_to include("user_card_id")
  end

  it "resets state across mode tabs and retains it through filters, lazy frames, sorting, and pagination" do
    create_cash_transaction
    get external_cash_transactions_path(share_token: share.token), params: navigation_params.merge(per_page: 1)

    expect(response).to have_http_status(:ok)
    document = response.parsed_body
    form = document.at_css("form#search_form")
    expect(form.at_css("input[name='search_term'][value='ledger search']")).to be_present
    expect(form.at_css("select[name='sort'] option[value='price'][selected]")).to be_present
    expect(form.at_css("select[name='direction'] option[value='desc'][selected]")).to be_present
    expect(form["data-turbo-frame"]).to eq("_top")
    expect(form["data-turbo-action"]).to eq("replace")

    card_tab = document.at_css("a[href*='/card_transactions']")
    expect_clean_mode_link(card_tab, external_card_transactions_path(share_token: share.token))
    expect(card_tab["data-turbo"]).to eq("false")
    expect(card_tab["data-turbo-frame"]).to be_nil
    expect(card_tab["data-turbo-action"]).to be_nil

    lazy_frame = document.at_css("turbo-frame#month_year_container_202609")
    lazy_uri = URI.parse(lazy_frame["src"])
    expect(lazy_uri.path).to eq(month_year_external_cash_transactions_path(share_token: share.token))
    expect(Rack::Utils.parse_nested_query(lazy_uri.query)).to include(
      "active_month_years" => active_months,
      "default_year" => "2026",
      "search_term" => "ledger search",
      "sort" => "price",
      "direction" => "desc",
      "per_page" => "1"
    )

    get lazy_frame["src"], headers: { "Turbo-Frame" => "month_year_container_202609" }

    next_link = response.parsed_body.css("a").find { |link| link.text.squish == "Next" }
    expect_scoped_link(next_link, external_cash_transactions_path(share_token: share.token), page: "2")
    expect(next_link["data-turbo-frame"]).to eq("_top")
    expect(next_link["data-turbo-action"]).to eq("replace")
  end

  it "preserves an explicitly empty month selection instead of restoring a default month" do
    get external_cash_transactions_path(share_token: share.token), params: { active_month_years: "[]", default_year: 2026 }

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.at_css("input[name='active_month_years']")["value"]).to eq("[]")
    expect(response.parsed_body.css("turbo-frame[id^='month_year_container_20']")).to be_empty
    expect(response.body).to include("No ledger entries found")
  end

  private

  def navigation_params
    {
      active_month_years: active_months,
      default_year: 2026,
      search_term: "  ledger   search ",
      sort: "price",
      direction: "desc"
    }
  end

  def expect_canonical_redirect(expected_path, **expected_query)
    expect(response).to have_http_status(:moved_permanently)
    uri = URI.parse(response.location)
    expect(uri.path).to eq(expected_path)
    expect(Rack::Utils.parse_nested_query(uri.query)).to include(expected_query.stringify_keys)
  end

  def redirect_query
    Rack::Utils.parse_nested_query(URI.parse(response.location).query)
  end

  def expect_scoped_link(node, expected_path, **expected_query)
    expect(node).to be_present
    uri = URI.parse(node["href"])
    expect(uri.path).to eq(expected_path)
    expect(Rack::Utils.parse_nested_query(uri.query)).to include(
      {
        "active_month_years" => active_months,
        "default_year" => "2026",
        "search_term" => "ledger search",
        "sort" => "price",
        "direction" => "desc"
      }.merge(expected_query.stringify_keys)
    )
  end

  def expect_clean_mode_link(node, expected_path)
    expect(node).to be_present
    uri = URI.parse(node["href"])
    expect(uri.path).to eq(expected_path)
    expect(uri.query).to be_nil
  end

  def create_cash_transaction
    account = create(:user_bank_account, :random, user: owner, bank: create(:bank, :random))
    transaction = create(
      :cash_transaction,
      user: owner,
      context:,
      user_bank_account: account,
      description: "LEDGER SEARCH",
      date: Time.zone.local(2026, 9, 10, 12),
      month: 9,
      year: 2026,
      price: -3000,
      cash_installments: [],
      category_transactions_attributes: [ { category_id: owner.built_in_category("EXCHANGE RETURN").id } ],
      entity_transactions_attributes: [ { entity_id: entity.id, is_payer: false, price: 0, price_to_be_returned: 0 } ],
      cash_installments_attributes: [
        { number: 1, date: Time.zone.local(2026, 9, 10, 12), month: 9, year: 2026, price: -1000, paid: true },
        { number: 2, date: Time.zone.local(2026, 9, 11, 12), month: 9, year: 2026, price: -2000, paid: true }
      ]
    )
    transaction.cash_installments
  end
end
