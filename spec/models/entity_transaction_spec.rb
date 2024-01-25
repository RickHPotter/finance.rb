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

RSpec.describe EntityTransaction, type: :model do
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
end
