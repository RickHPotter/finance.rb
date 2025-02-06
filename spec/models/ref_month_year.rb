# frozen_string_literal: true

require "rails_helper"

RSpec.describe RefMonthYear, type: :model do
  describe "[ activerecord validations ]" do
    it "returns the month and year in the expected format" do
      expect(RefMonthYear.new(5, 2023).month_year).to eq("MAI <23>")
      expect(RefMonthYear.new(5, 23).month_year).to eq("MAI <23>")
    end

    it "returns an instance of itself based on a string in the month_year format" do
      ref_month_year = RefMonthYear.from_string("MAI <23>")
      expect(ref_month_year.month).to eq(5)
      expect(ref_month_year.year).to eq(2023)
      expect(ref_month_year.month_year).to eq("MAI <23>")
    end

    it "returns a range of dates based on a pivot date, a max date it can range to and the interval" do
      expect(RefMonthYear.get_span(Date.new(2023, 1, 1), Date.new(2024, 1, 1), 6)).to eq([ Date.new(2022, 9, 1), Date.new(2023, 2, 28) ])
      expect(RefMonthYear.get_span(Date.new(2024, 1, 1), Date.new(2024, 1, 1), 6)).to eq([ Date.new(2023, 8, 1), Date.new(2024, 1, 31) ])
      expect(RefMonthYear.get_span(Date.new(2025, 1, 1), Date.new(2024, 1, 1), 6)).to eq([ Date.new(2023, 8, 1), Date.new(2024, 1, 31) ])
    end
  end
end
