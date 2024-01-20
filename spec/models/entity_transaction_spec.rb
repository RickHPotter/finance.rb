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
  let!(:card_transaction) { FactoryBot.create(:card_transaction, :random, :with_entity_transactions) }
  let!(:entity_transaction) { FactoryBot.create(:entity_transaction, :random) }

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
      it 'creates the corresponding entity_transaction' do
        expect(card_transaction.entities).to_not be_empty
        expect(card_transaction.paying_entities).to_not be_empty
      end
    end

    context '( card_transaction creation with entity_transactions under updates in entity_transaction_attributes )' do
      it 'destroys the existing entity_transactions when emptying entity_transaction_attributes' do
        card_transaction.update(entity_transaction_attributes: [])
        expect(card_transaction.entities).to be_empty
        expect(card_transaction.paying_entities).to be_empty
      end

      it 'destroys the existing entity_transactions and then creates them again' do
        card_transaction.update(entity_transaction_attributes: [])
        card_transaction.update(
          entity_transaction_attributes: [{
            entity: FactoryBot.create(:entity, :random, user: card_transaction.user),
            transactable: card_transaction,
            is_payer: false
          }]
        )
        expect(card_transaction.entities).to_not be_empty
        expect(card_transaction.paying_entities).to be_empty
      end
    end
  end
end
