# frozen_string_literal: true

# == Schema Information
#
# Table name: exchanges
#
#  id                    :bigint           not null, primary key
#  exchange_type         :integer          default("non_monetary"), not null
#  number                :integer          default(1), not null
#  starting_price        :decimal(, )      not null
#  price                 :decimal(, )      not null
#  entity_transaction_id :bigint           not null
#  money_transaction_id  :bigint
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#
require 'rails_helper'

RSpec.describe Exchange, type: :model do
  let!(:entity_transaction) { FactoryBot.create(:entity_transaction, :random, is_payer: true, exchanges_count: 1) }
  let!(:entity_transaction_not_payer) { FactoryBot.create(:entity_transaction, :random, is_payer: false) }
  let!(:exchange) { entity_transaction.exchanges.first }

  describe '[ activerecord validations ]' do
    context '( presence, uniqueness, etc )' do
      it 'is valid with valid attributes' do
        expect(exchange).to be_valid
      end

      %i[exchange_type price].each do |attribute|
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
    context '( entity_transaction creation with exchanges )' do
      it 'creates the corresponding exchange' do
        expect(entity_transaction.exchanges.count).to eq(1)
      end
    end

    context '( entity_transaction creation with exchanges under updates in exchanges_count )' do
      before do
        entity_transaction.update(exchanges_count: 2)
      end

      it 'updates the amount of exchanges to two' do
        expect(entity_transaction.exchanges.count).to eq(2)
      end

      it 'updates the amount of exchanges to two then back to one' do
        entity_transaction.update(exchanges_count: 1)
        expect(entity_transaction.exchanges.count).to eq(1)
      end
    end

    context '( entity_transaction creation with exchanges under updates in exchange_attributes )' do
      it 'destroys the existing exchanges when emptying exchange_attributes' do
        entity_transaction.update(is_payer: false, exchange_attributes: [])
        expect(entity_transaction.exchanges).to be_empty
      end

      it 'destroys the existing exchanges and then creates them again' do
        exchange_attributes = entity_transaction.exchange_attributes

        entity_transaction.update(is_payer: false, exchange_attributes: [])
        entity_transaction.update(is_payer: true, exchange_attributes:)
        expect(entity_transaction.exchanges).to_not be_empty
      end
    end

    context '( entity_transaction creation with exchanges under updates in is_payer )' do
      before do
        entity_transaction.update(is_payer: false)
      end

      it 'destroys the amount of existing exchanges' do
        expect(entity_transaction.exchanges.count).to eq(0)
      end

      it 'creates exchanges after updating is_payer again' do
        entity_transaction.update(is_payer: true)
        expect(entity_transaction.exchanges.count).to eq(1)
      end
    end

    context '( entity_transaction creation with exchanges under updates in exchange_type )' do
      it 'does not generate any exchange' do
        expect(entity_transaction_not_payer.exchanges).to be_empty
      end

      it 'generate a new exchange after updating is_payer' do
        entity_transaction_not_payer.update(is_payer: true, exchanges_count: 1)
        expect(entity_transaction_not_payer.exchanges).to_not be_empty
      end
    end

    # FIXME: create method for this
    context '( entity_transaction switching exchange_type )' do
      before do
        # exchange.update(exchange_type: 0)
      end

      it 'creates no money_transaction' do
        # expect(exchange.money_transaction).to be(nil)
      end

      it 'creates a single money_transaction' do
        # exchange.update(exchange_type: 1)
        # expect(exchange.money_transaction).to_not be(nil)
      end
    end
  end
end
