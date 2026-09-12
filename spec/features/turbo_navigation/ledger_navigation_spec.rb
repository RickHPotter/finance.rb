# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Ledger Turbo navigation", type: :feature do
  let(:owner) { create(:user, :random) }
  let(:entity) { create(:entity, user: owner, entity_name: "Navigation ledger") }
  let(:share) { Ledgers::Shares::Create.call(entity:, context: owner.main_context) }
  let(:active_months) { [ 202_609 ].to_json }

  it "keeps the final filter state canonical through mode changes, refresh, Back, and Forward" do
    sign_in owner
    visit entities_path
    visit external_cash_transactions_path(share_token: share.token, active_month_years: active_months, default_year: 2026)

    fill_in "search_term", with: "discarded search"
    fill_in "search_term", with: "canonical search"
    select I18n.t("ledgers.filter.sorts.price"), from: "ledger_sort"
    select I18n.t("ledgers.filter.directions.desc"), from: "ledger_direction"

    expect(page).to have_current_path(/search_term=canonical(?:\+|%20)search/)
    click_on I18n.t("ledgers.navigation.card")
    expect(page).to have_current_path(%r{/card_transactions})

    final_uri = URI.parse(page.current_url)
    expect(final_uri.path).to eq(external_card_transactions_path(share_token: share.token))
    expect(Rack::Utils.parse_nested_query(final_uri.query)).to include(
      "active_month_years" => active_months,
      "default_year" => "2026",
      "search_term" => "canonical search",
      "sort" => "price",
      "direction" => "desc"
    )

    refresh_browser_at(final_uri.request_uri)
    browser_back_to(entities_path)
    browser_forward_to(final_uri.request_uri)
  end

  it "keeps a deliberately empty month selection after the reactive refresh" do
    visit external_cash_transactions_path(share_token: share.token, active_month_years: active_months, default_year: 2026)

    month_button = find("button[data-month-year='202609']")
    page.execute_script("arguments[0].dispatchEvent(new MouseEvent('mousedown', { bubbles: true }))", month_button.native)
    page.execute_script("arguments[0].dispatchEvent(new MouseEvent('mouseup', { bubbles: true }))", month_button.native)

    expect(page).to have_current_path(/active_month_years=%5B%5D/)
    expect(find("input[name='active_month_years']", visible: :all).value).to eq("[]")
    expect(page).to have_no_css("turbo-frame#month_year_container_202609", visible: :all)
    expect(page).to have_text(I18n.t("ledgers.empty.title"))
  end
end
