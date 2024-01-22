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
  let!(:entity_transaction) do
    FactoryBot.create(:entity_transaction, :random, :transactable_card_transaction, is_payer: true, exchanges_count: 1)
  end
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

    context '( entity_transaction creation with exchanges under updates in exchange_attributes )' do
      before do
        entity_transaction.update(exchange_attributes: [{ price: 0.02 }, { price: 0.03 }])
      end

      it 'updates the amount of exchanges to two' do
        expect(entity_transaction.exchanges.count).to eq(2)
      end

      it 'updates the amount of exchanges to two then back to one' do
        entity_transaction.update(exchange_attributes: [{ price: 0.02 }])
        expect(entity_transaction.exchanges.count).to eq(1)
      end
    end

    context '( entity_transaction creation with exchanges under updates in exchange_attributes )' do
      it 'destroys the existing exchanges when emptying exchange_attributes' do
        entity_transaction.update(is_payer: false, exchange_attributes: [])
        expect(entity_transaction.exchanges).to be_empty
      end

      it 'destroys the existing exchanges and then creates them again' do
        entity_transaction.update(is_payer: false, exchange_attributes: [])
        entity_transaction.update(is_payer: true, exchange_attributes: [{ exchange_type: :monetary, price: 0.04 }])
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
        entity_transaction.update(is_payer: true, exchange_attributes: [{ exchange_type: :monetary, price: 0.16 }])
        expect(entity_transaction.exchanges.count).to eq(1)
      end
    end

    context '( entity_transaction creation with exchanges under updates in exchange_type )' do
      it 'does not generate any exchange' do
        expect(entity_transaction_not_payer.exchanges).to be_empty
      end

      it 'generate a new exchange after updating is_payer' do
        entity_transaction_not_payer.update(is_payer: true, exchange_attributes: [{ price: 0.06 }])
        expect(entity_transaction_not_payer.exchanges).to_not be_empty
      end
    end

    context '( exchange creation with exchange_type monetary )' do
      before do
        exchange.monetary!
      end

      it 'categories are set correctly for the beginning of the flow (transactable) and end (money_transaction) ' do
        expect(exchange.entity_transaction.transactable.categories.pluck(:category_name)).to include('Exchange')
        expect(exchange.money_transaction.categories.pluck(:category_name)).to include('Exchange Return')
      end

      it 'generates a money_transaction' do
        expect(exchange.money_transaction).to_not be(nil)
      end

      it 'generates no money_transaction after another update to non_monetary' do
        exchange.non_monetary!
        expect(exchange.money_transaction).to be(nil)
      end
    end

    context '( exchange switching exchange_type to non_monetary )' do
      before do
        exchange.non_monetary!
      end

      it 'generates no money_transaction' do
        expect(exchange.money_transaction).to be(nil)
      end

      it 'generates a money_transaction after another update to monetary' do
        exchange.monetary!
        expect(exchange.money_transaction).to_not be(nil)
      end

      it 'changes entity_transaction status to finished' do
        expect(exchange.entity_transaction.finished?).to be(true)
      end
    end
  end
end
