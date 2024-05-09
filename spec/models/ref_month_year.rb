# frozen_string_literal: true

require "rails_helper"

RSpec.describe RefMonthYear, type: :model do
  describe "[ activerecord validations ]" do
    it "is returns the month and year in the expected format" do
      expect(RefMonthYear.new(5, 2023).month_year).to eq("MAI <23>")
    end
  end
end
