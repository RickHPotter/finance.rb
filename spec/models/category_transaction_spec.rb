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

RSpec.describe CategoryTransaction, type: :model do
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
end
