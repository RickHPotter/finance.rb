# frozen_string_literal: true

# == Schema Information
#
# Table name: exchanges
#
#  id                    :bigint           not null, primary key
#  exchange_type         :integer          default("non_monetary"), not null
#  number                :integer          default(1), not null
#  starting_price        :integer          not null
#  price                 :integer          not null
#  entity_transaction_id :bigint           not null
#  money_transaction_id  :bigint
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#
require "rails_helper"

RSpec.describe Exchange, type: :model do
  let!(:subject) { build(:exchange, :random) }

  describe "[ activerecord validations ]" do
    context "( presence, uniqueness, etc )" do
      it "is valid with valid attributes" do
        expect(subject).to be_valid
      end

      %i[exchange_type number price].each do |attribute|
        it { should validate_presence_of(attribute) }
      end
    end

    context "( associations )" do
      it { should belong_to(:entity_transaction) }
      it { should belong_to(:money_transaction).optional }

      it { should define_enum_for(:exchange_type).with_values(non_monetary: 0, monetary: 1) }
    end
  end
end
