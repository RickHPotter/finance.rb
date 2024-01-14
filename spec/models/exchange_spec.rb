# frozen_string_literal: true

# == Schema Information
#
# Table name: exchanges
#
#  id                    :bigint           not null, primary key
#  exchange_type         :integer          default("non_monetary"), not null
#  number                :integer          default(1), not null
#  amount_to_be_returned :decimal(, )      not null
#  amount_returned       :decimal(, )      not null
#  entity_transaction_id :bigint           not null
#  money_transaction_id  :bigint
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#
require 'rails_helper'

RSpec.describe Exchange, type: :model do
  let!(:entity_transaction) { FactoryBot.create(:entity_transaction, :random, is_payer: true, exchanges_count: 1) }
  let!(:exchange) { entity_transaction.exchanges.first }

  describe '[ activerecord validations ]' do
    context '( presence, uniqueness, etc )' do
      it 'is valid with valid attributes' do
        expect(exchange).to be_valid
      end

      %i[exchange_type amount_to_be_returned amount_returned].each do |attribute|
        it_behaves_like 'validate_nil', :exchange, attribute
        it_behaves_like 'validate_blank', :exchange, attribute
      end
    end

    context '( associations )' do
      %i[entity_transaction money_transaction].each do |model|
        it "belongs_to #{model}" do
          expect(exchange).to respond_to model
        end
      end
    end
  end

  describe '[ business logic ]' do
    context '( card_transaction creation with entity_transaction_attributes )' do
      it 'creates the corresponding exchange' do
        expect(entity_transaction.exchanges.count).to eq(1)
      end
    end

    # FIXME: create method for this
    context '( card_transaction update with entity_transaction_attributes )' do
      before do
        # entity_transaction.update(exchanges_count: 2)
      end
      it 'creates the corresponding exchange' do
        # expect(entity_transaction.exchanges.count).to eq(2)
      end
    end

    # FIXME: create method for this
    context '( when new exchanges are created )' do
      before do
        # exchange.update(exchange_type: 1)
      end

      it 'creates a single money_transaction' do
        # expect(exchange.money_transaction).to_not be(nil)
      end
    end
  end
end
