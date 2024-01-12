# frozen_string_literal: true

# == Schema Information
#
# Table name: transaction_entities
#
#  id                :bigint           not null, primary key
#  is_payer          :boolean          default(FALSE), not null
#  status            :integer          default("pending"), not null
#  price             :decimal(, )      default(0.0), not null
#  transactable_type :string           not null
#  transactable_id   :bigint           not null
#  entity_id         :bigint           not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#
require 'rails_helper'

include FactoryHelper

RSpec.describe CardTransaction, type: :model do
  # TODO: add tests for status = :pending after the implementation of Exchange
  let!(:transaction_entity) { FactoryBot.create(:transaction_entity, :random, is_payer: false) }

  describe '[ activerecord validations ]' do
    context '( presence, uniquness, etc )' do
      it 'is valid with valid attributes' do
        expect(transaction_entity).to be_valid
      end

      %i[is_payer].each do |attribute|
        it_behaves_like 'validate_nil', :transaction_entity, attribute
        it_behaves_like 'validate_blank', :transaction_entity, attribute
      end
    end

    context '( associations )' do
      %i[transactable entity].each do |model|
        it "belongs_to #{model}" do
          expect(transaction_entity).to respond_to model
        end
      end

      %i[exchanges].each do |model|
        it "has_many #{model}" do
          expect(transaction_entity).to respond_to model
        end
      end
    end
  end
end
