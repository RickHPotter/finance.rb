# frozen_string_literal: true

require "rails_helper"

RSpec.describe InvestmentType, type: :model do
  let(:subject) { build(:investment_type) }

  describe "[ activerecord validations ]" do
    context "( presence, uniqueness, etc )" do
      it "is valid with valid attributes" do
        expect(subject).to be_valid
      end

      it { should validate_presence_of(:investment_type_name_fallback) }
      it { should validate_uniqueness_of(:investment_type_code).allow_nil }
    end

    context "( associations )" do
      it { should have_many(:investments) }
      it { should have_many(:cash_transactions) }
    end
  end

  describe "[ public methods ]" do
    it "returns the fallback when investment_type_code is blank" do
      subject.investment_type_code = nil

      expect(subject.display_name).to eq(subject.investment_type_name_fallback)
    end

    it "returns a translated name when investment_type_code is present" do
      subject.investment_type_code = "investment"
      subject.investment_type_name_fallback = "Fallback"

      expect(subject.display_name).to eq(I18n.t("activerecord.attributes.investment_type.investment", default: "Fallback"))
    end
  end
end

# == Schema Information
#
# Table name: investment_types
# Database name: primary
#
#  id                            :bigint           not null, primary key
#  built_in                      :boolean          default(FALSE), not null, indexed
#  investment_type_code          :string           uniquely indexed
#  investment_type_name_fallback :string           not null
#  created_at                    :datetime         not null
#  updated_at                    :datetime         not null
#
# Indexes
#
#  index_investment_types_on_built_in              (built_in)
#  index_investment_types_on_investment_type_code  (investment_type_code) UNIQUE
#
