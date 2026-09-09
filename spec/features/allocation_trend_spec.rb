# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Allocation trend dashboards", type: :feature do
  let(:user) { create(:user, :random) }

  before { sign_in user }

  it "loads an exact category report and restores changed filters from the URL" do
    bank = create(:bank, :random)
    account = create(:user_bank_account, user:, bank:)
    category = create(:category, user:, category_name: "TRAVEL REPORT")
    entity = create(:entity, user:, entity_name: "TREND COUNTERPART")
    transaction = create(
      :cash_transaction,
      user:,
      context: user.main_context,
      user_bank_account: account,
      date: Date.new(2026, 7, 10),
      month: 7,
      year: 2026,
      price: -1_500
    )
    create(:category_transaction, transactable: transaction, category:)
    create(:entity_transaction, transactable: transaction, entity:)
    path = category_path(
      category,
      from_date: "2026-07-01",
      to_date: "2026-07-31",
      granularity: "month",
      paid_state: "all",
      direction: "all"
    )

    visit path
    trend = find("#category_#{category.id}_trend")
    page.execute_script("arguments[0].scrollIntoView({ block: 'center' })", trend)

    expect(trend).to have_css("[data-allocation-trend-target='content']:not(.hidden)")
    expect(trend).to have_text("TREND COUNTERPART")
    expect(trend).to have_css("a[href*='/cash_transactions']")

    find("#category_#{category.id}_trend_direction").select(I18n.t("reports.allocation_trend.options.direction.outcome"))
    expect(page).to have_current_path(category_path(category), ignore_query: true)
    expect(Rack::Utils.parse_query(URI.parse(page.current_url).query)).to include(
      "from_date" => "2026-07-01",
      "to_date" => "2026-07-31",
      "granularity" => "month",
      "paid_state" => "all",
      "direction" => "outcome",
      "sort" => "date_asc"
    )

    updated_path = URI.parse(page.current_url).request_uri
    refresh_browser_at(updated_path)
    expect(page).to have_select("category_#{category.id}_trend_direction", selected: I18n.t("reports.allocation_trend.options.direction.outcome"))
    expect(page).to have_css("#category_#{category.id}_trend [data-allocation-trend-target='content']:not(.hidden)")
  end
end
