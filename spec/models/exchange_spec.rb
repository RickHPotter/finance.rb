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
  let!(:exchange) { FactoryBot.create(:exchange, :random) }

  describe '[ activerecord validations ]' do
    context '( presence, uniquness, etc )' do
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
    context '( when new exchanges are created )' do
      before do
        exchange.update(exchange_type: 1)
        # exchange.reload
      end

      it 'creates a single money_transaction' do
        # expect(exchange.money_transaction).to_not be(nil)
      end
    end
  end
end
