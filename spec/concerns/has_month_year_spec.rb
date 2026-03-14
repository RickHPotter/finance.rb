# frozen_string_literal: true

require "rails_helper"

RSpec.describe HasMonthYear, type: :concern do
  describe "[ concern behaviour ]" do
    it "fills month and year from date when they are blank" do
      investment = build(:investment, date: Date.new(2026, 3, 14), month: nil, year: nil)

      investment.save!

      expect(investment.month).to eq(3)
      expect(investment.year).to eq(2026)
    end

    it "provides month_year and date helper methods" do
      investment = build(:investment, date: Date.new(2026, 3, 14), month: 3, year: 2026)

      expect(investment.month_year).to eq("MAR <26>")
      expect(investment.beginning_of_month).to eq(Date.new(2026, 3, 1))
      expect(investment.end_of_month).to eq(Date.new(2026, 3, 31))
      expect(investment.next_date(date: Date.new(2026, 3, 14), days: 1, months: 1)).to eq(Date.new(2026, 4, 1))
    end
  end
end
