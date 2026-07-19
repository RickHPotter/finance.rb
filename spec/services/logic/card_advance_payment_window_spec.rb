# frozen_string_literal: true

require "rails_helper"

RSpec.describe Logic::CardAdvancePaymentWindow, type: :service do
  let(:user) { create(:user, :random) }
  let(:user_card) { create(:user_card, :random, user:) }
  let(:context) { user.main_context }

  subject(:window) { described_class.new(user_card:, context:, month: 7, year: 2026) }

  before do
    create(
      :reference,
      user_card:,
      context:,
      month: 6,
      year: 2026,
      reference_date: Date.new(2026, 6, 20),
      reference_closing_date: Date.new(2026, 6, 10),
      skip_reference_closing_date_calculation: true
    )
    create(
      :reference,
      user_card:,
      context:,
      month: 7,
      year: 2026,
      reference_date: Date.new(2026, 7, 20),
      reference_closing_date: Date.new(2026, 7, 10),
      skip_reference_closing_date_calculation: true
    )
  end

  it "calculates context-scoped minimum and maximum local datetimes" do
    other_context = create(:context, user:, name: "Other card cycle")
    create(
      :reference,
      user_card:,
      context: other_context,
      month: 7,
      year: 2026,
      reference_date: Date.new(2026, 7, 25),
      reference_closing_date: Date.new(2026, 7, 15),
      skip_reference_closing_date_calculation: true
    )

    expect(window.minimum).to eq(Time.zone.local(2026, 6, 10))
    expect(window.maximum).to eq(Time.zone.local(2026, 7, 20))
  end

  it "accepts inclusive minute boundaries and rejects moments immediately outside them" do
    expect(window).to be_cover(window.minimum)
    expect(window).to be_cover(window.maximum)
    expect(window).not_to be_cover(window.minimum - 1.minute)
    expect(window).not_to be_cover(window.maximum + 1.minute)
  end

  it "uses the current minute inside a complete window and otherwise defaults to its maximum" do
    inside = Time.zone.local(2026, 7, 1, 12, 34, 59)

    expect(window.default_datetime(now: inside)).to eq(Time.zone.local(2026, 7, 1, 12, 34))
    expect(window.default_datetime(now: window.maximum + 1.minute)).to eq(window.maximum)
  end

  it "is unavailable for invalid cycles and cycles without reference boundaries" do
    invalid_window = described_class.new(user_card:, context:, month: 13, year: 2026)
    missing_window = described_class.new(user_card:, context:, month: 9, year: 2026)

    expect(invalid_window).not_to be_available
    expect(missing_window).not_to be_available
    expect(missing_window).not_to be_cover(Time.zone.local(2026, 9, 1))
  end
end
