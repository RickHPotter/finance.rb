# frozen_string_literal: true

# == Schema Information
#
# Table name: category_transactions
#
#  id                :bigint           not null, primary key
#  category_id       :bigint           not null
#  transactable_type :string           not null
#  transactable_id   :bigint           not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#
require 'rails_helper'

include FactoryHelper

RSpec.describe CategoryTransaction, type: :model do
  let!(:card_transaction) { FactoryBot.create(:card_transaction, :random, :with_category_transactions) }
  let!(:category_transaction) { FactoryBot.create(:category_transaction, :random) }

  describe '[ activerecord validations ]' do
    context '( presence, uniqueness, etc )' do
      it 'is valid with valid attributes' do
        expect(category_transaction).to be_valid
      end

      it_behaves_like 'validate_uniqueness_combination', :category_transaction, :category, :transactable
    end

    context '( associations )' do
      %i[transactable category].each do |model|
        it "belongs_to #{model}" do
          expect(category_transaction).to respond_to model
        end
      end
    end
  end

  describe '[ business logic ]' do
    context '( card_transaction creation with category_transaction_attributes )' do
      it 'creates the corresponding category_transaction' do
        expect(card_transaction.category_transactions.count).to eq(1)
      end
    end

    context '( card_transaction creation with category_transactions under updates in category_transaction_attributes )' do
      it 'destroys the existing category_transactions when emptying category_transaction_attributes' do
        card_transaction.update(category_transaction_attributes: [])
        expect(card_transaction.custom_categories).to be_empty
      end

      it 'destroys the existing category_transactions and then creates them again' do
        category_transaction_attributes = card_transaction.category_transaction_attributes

        card_transaction.update(category_transaction_attributes: [])
        card_transaction.update(category_transaction_attributes:)
        expect(card_transaction.custom_categories).to_not be_empty
      end
    end
  end
end
