# frozen_string_literal: true

require "rails_helper"

RSpec.describe Reports::QueryState do
  subject(:state) { described_class.new(params, today: Date.new(2026, 9, 9)) }

  let(:params) { {} }

  it "uses a bounded rolling twelve-month default" do
    expect(state).to have_attributes(
      from_date: Date.new(2025, 10, 1),
      to_date: Date.new(2026, 9, 30),
      granularity: "month",
      paid_state: "all",
      direction: "all",
      sort: "date_asc"
    )
  end

  it "parses and serializes canonical explicit state" do
    params.merge!(
      from_date: "2026-08-01",
      to_date: "2026-09-09",
      granularity: "day",
      paid_state: "pending",
      direction: "outcome",
      sort: "amount_desc"
    )

    expect(state.canonical_params).to eq(
      from_date: "2026-08-01",
      to_date: "2026-09-09",
      granularity: "day",
      paid_state: "pending",
      direction: "outcome",
      sort: "amount_desc"
    )
  end

  it "rejects malformed, impossible, and reversed dates with localized errors" do
    invalid_states = [
      [ { from_date: "2026-9-01" }, :invalid_date ],
      [ { to_date: "2026-02-30" }, :invalid_date ],
      [ { from_date: "2026-09-02", to_date: "2026-09-01" }, :invalid_range ]
    ]

    invalid_states.each do |invalid_params, code|
      expect { described_class.new(invalid_params, today: Date.new(2026, 9, 9)) }
        .to raise_error(described_class::InvalidState) { |error| expect(error.code).to eq(code) }
    end
  end

  it "rejects ranges above the selected granularity limit" do
    expect do
      described_class.new({ from_date: "2026-01-01", to_date: "2026-04-04", granularity: "day" })
    end.to raise_error(described_class::InvalidState) { |error| expect(error.code).to eq(:range_too_large) }

    expect do
      described_class.new({ from_date: "2024-09-01", to_date: "2026-09-30", granularity: "month" })
    end.to raise_error(described_class::InvalidState) { |error| expect(error.code).to eq(:range_too_large) }
  end

  it "accepts the exact day and month limits" do
    day_state = described_class.new({ from_date: "2026-01-01", to_date: "2026-04-03", granularity: "day" })
    month_state = described_class.new({ from_date: "2024-10-01", to_date: "2026-09-30", granularity: "month" })

    expect(day_state).to have_attributes(from_date: Date.new(2026, 1, 1), to_date: Date.new(2026, 4, 3))
    expect(month_state).to have_attributes(from_date: Date.new(2024, 10, 1), to_date: Date.new(2026, 9, 30))
  end

  it "rejects unknown enum state" do
    {
      granularity: "week",
      paid_state: "overdue",
      direction: "sideways",
      sort: "created_at desc"
    }.each do |key, value|
      expect { described_class.new({ key => value }) }
        .to raise_error(described_class::InvalidState) { |error| expect(error.code).to eq(:"invalid_#{key}") }
    end
  end

  it "requires its default sort to be in the report-specific allowlist" do
    expect do
      described_class.new({}, allowed_sorts: %w[amount_desc], default_sort: "date_asc")
    end.to raise_error(ArgumentError, "default sort must be allowlisted")
  end
end
