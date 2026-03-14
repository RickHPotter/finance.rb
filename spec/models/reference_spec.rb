# frozen_string_literal: true

require "rails_helper"

RSpec.describe Reference, type: :model do
  let(:user_card) { create(:user_card, :random, due_date_day: 12, days_until_due_date: 7) }
  let(:subject) do
    described_class.new(
      user_card:,
      month: 3,
      year: 2026,
      reference_date: Date.new(2026, 3, 12)
    )
  end

  describe "[ activerecord validations ]" do
    context "( presence, uniqueness, etc )" do
      it "is valid with valid attributes" do
        expect(subject).to be_valid
      end

      %i[month year reference_date].each do |attribute|
        it { should validate_presence_of(attribute) }
      end

      it { should belong_to(:user_card) }

      it "validates uniqueness of month and year scoped to user_card_id" do
        create(:user_card, :random) # warm shoulda relation state
        create(:reference, user_card:, month: 3, year: 2026, reference_date: Date.new(2026, 3, 12))

        duplicate = build(:reference, user_card:, month: 3, year: 2026, reference_date: Date.new(2026, 4, 12))

        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:user_card_id]).to be_present
      end

      it "validates uniqueness of reference_date scoped to user_card_id" do
        create(:reference, user_card:, month: 3, year: 2026, reference_date: Date.new(2026, 3, 12))

        duplicate = build(:reference, user_card:, month: 4, year: 2026, reference_date: Date.new(2026, 3, 12))

        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:reference_date]).to be_present
      end
    end
  end

  describe "[ business logic ]" do
    it "sets reference_closing_date from the user_card cycle" do
      subject.save!

      expect(subject.reference_closing_date).to eq(Date.new(2026, 3, 5))
    end

    it ".find_by_month_year finds the matching record" do
      subject.save!

      expect(described_class.find_by_month_year(RefMonthYear.new(3, 2026))).to eq(subject)
    end
  end
end
