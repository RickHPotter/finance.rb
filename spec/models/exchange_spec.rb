# frozen_string_literal: true

require "rails_helper"

RSpec.describe Exchange, type: :model do
  let(:subject) { build(:exchange, :random) }

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
      it { should belong_to(:cash_transaction).optional }
      it { should define_enum_for(:exchange_type).with_values(non_monetary: 0, monetary: 1) }
    end
  end
end

# == Schema Information
#
# Table name: exchanges
#
#  id                    :bigint           not null, primary key
#  bound_type            :string           default("standalone"), not null
#  exchange_type         :integer          default("non_monetary"), not null
#  exchanges_count       :integer          default(0), not null
#  number                :integer          default(1), not null
#  price                 :integer          not null
#  starting_price        :integer          not null
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  cash_transaction_id   :bigint           indexed
#  entity_transaction_id :bigint           not null, indexed
#
# Indexes
#
#  index_exchanges_on_cash_transaction_id    (cash_transaction_id)
#  index_exchanges_on_entity_transaction_id  (entity_transaction_id)
#
# Foreign Keys
#
#  fk_rails_...  (cash_transaction_id => cash_transactions.id)
#  fk_rails_...  (entity_transaction_id => entity_transactions.id)
#
