# frozen_string_literal: true

# == Schema Information
#
# Table name: installments
#
#  id               :integer          not null, primary key
#  installable_type :string           not null
#  installable_id   :integer          not null
#  price            :decimal(10, 2)   default(0.0), not null
#  number           :integer          default(1), not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#
require 'rails_helper'

RSpec.describe Installment, type: :model do
  # FIXME: move shared_examples to be used in money_transaction as well
  let(:card_transaction) { FactoryBot.build(:card_transaction, :random, installments_count: 1) }

  # FIXME: UNTESTED with p and shit
  shared_examples 'installments cop' do
    it 'creates the expected amount of installments' do
      expect(card_transaction.installments_count).to eq card_transaction.installments.count
    end

    it 'applies the right relationship to the transaction' do
      card_transaction.installments.each do |installment|
        expect(installment.installable_id).to eq card_transaction.id
        expect(installment.installable_type).to eq card_transaction.class.name
      end
    end

    it 'sums the installments correctly' do
      expect(card_transaction.installments.sum(:price)).to eq card_transaction.price
    end
  end

  describe '[ business logic ]' do
    context '( when installments_count is 1 )' do
      before do
        card_transaction.save
      end

      include_examples 'installments cop'
    end

    context '( when installments_count is 2 )' do
      before do
        card_transaction.installments_count = 2
        card_transaction.save
      end

      include_examples 'installments cop'
    end

    context '( when installments_count is 3 )' do
      before do
        card_transaction.installments_count = 3
        card_transaction.save
      end

      include_examples 'installments cop'
    end
  end
end
