# frozen_string_literal: true

require "rails_helper"

RSpec.describe HealthCheck::Page do
  it "defaults to 25 rows, caps at 100, and freezes live page metadata" do
    records = 120.times.map { |id| { id: } }

    default_page = described_class.from(records:, page: nil, per_page: nil, filters: { issue_filter: "" })
    bounded_page = described_class.from(records:, page: 1, per_page: 500, filters: { issue_filter: "drift" })

    expect(default_page).to have_attributes(number: 1, per_page: 25, total_count: 120, total_pages: 5, next_page: 2, previous_page: nil)
    expect(default_page.records.size).to eq(25)
    expect(bounded_page).to have_attributes(per_page: 100, total_pages: 2)
    expect(bounded_page.records.size).to eq(100)
    expect(bounded_page.filters).to eq("issue_filter" => "drift", "per_page" => 100)
    expect(bounded_page).to be_frozen
    expect(bounded_page.records).to be_frozen
    expect(bounded_page.filters).to be_frozen
  end

  it "normalizes malformed and out-of-range pages to the first page" do
    records = 30.times.map { |id| { id: } }

    malformed = described_class.from(records:, page: "invalid", per_page: 10)
    out_of_range = described_class.from(records:, page: 50, per_page: 10)

    expect(malformed.number).to eq(1)
    expect(out_of_range.number).to eq(1)
    expect(out_of_range.records).to eq(records.first(10))
  end
end
