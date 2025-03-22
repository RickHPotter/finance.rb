# frozen_string_literal: true

require "rails_helper"

RSpec.describe Bank, type: :model do
  let(:subject) { build(:bank, :random) }

  describe "[ activerecord validations ]" do
    context "( presence, uniqueness, etc )" do
      it "is valid with valid attributes" do
        expect(subject).to be_valid
      end

      %i[bank_name bank_code].each do |attribute|
        it { should validate_presence_of(attribute) }
      end

      it { should validate_uniqueness_of(:bank_name).scoped_to(:bank_code) }
    end

    context "( associations )" do
      hm_models = %i[cards user_bank_accounts]

      hm_models.each { |model| it { should have_many(model) } }
    end
  end
end

# == Schema Information
#
# Table name: banks
#
#  id         :bigint           not null, primary key
#  bank_code  :integer          not null
#  bank_name  :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
