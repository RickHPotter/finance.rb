# frozen_string_literal: true

# == Schema Information
#
# Table name: entity_transactions
#
#  id                :bigint           not null, primary key
#  is_payer          :boolean          default(FALSE), not null
#  status            :integer          default("pending"), not null
#  price             :decimal(, )      default(0.0), not null
#  exchanges_count   :integer          default(0), not null
#  entity_id         :bigint           not null
#  transactable_type :string           not null
#  transactable_id   :bigint           not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#
require 'rails_helper'

include FactoryHelper

RSpec.describe EntityTransaction, type: :model do
  # TODO: add tests for status = :pending after the implementation of Exchange
  let!(:entity_transaction) { FactoryBot.create(:entity_transaction, :random, is_payer: false) }

  describe '[ activerecord validations ]' do
    context '( presence, uniqueness, etc )' do
      it 'is valid with valid attributes' do
        expect(entity_transaction).to be_valid
      end

      %i[is_payer].each do |attribute|
        it_behaves_like 'validate_nil', :entity_transaction, attribute
        it_behaves_like 'validate_blank', :entity_transaction, attribute
      end

      it_behaves_like 'validate_uniqueness_combination', :entity_transaction, :entity, :transactable
    end

    context '( associations )' do
      %i[transactable entity].each do |model|
        it "belongs_to #{model}" do
          expect(entity_transaction).to respond_to model
        end
      end

      %i[exchanges].each do |model|
        it "has_many #{model}" do
          expect(entity_transaction).to respond_to model
        end
      end
    end
  end

  describe '[ business logic ]' do
    context '( card_transaction creation with entity_transaction_attributes )' do
      # TODO: move this to card_transaction factory like exchange was moved to entity_transaction factory
      # TODO: do the same for category_transaction
      it 'creates the corresponding entity_transaction' do
        entity_transaction_attributes = [{
          entity_id: User.first.entities.ids.sample, is_payer: true, price: 4.00,
          exchange_attributes: [
            { exchange_type: :monetary, amount_to_be_returned: 2.00, amount_returned: 0.00 },
            { exchange_type: :monetary, amount_to_be_returned: 2.00, amount_returned: 0.00 }
          ]
        }]
        card_transaction = FactoryBot.create(:card_transaction, entity_transaction_attributes:)
        expect(card_transaction.entity_transactions.count).to eq(1)
      end
    end
  end
end
