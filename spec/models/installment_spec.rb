# frozen_string_literal: true

# == Schema Information
#
# Table name: installments
#
#  id               :bigint           not null, primary key
#  price            :decimal(10, 2)   default(0.0), not null
#  number           :integer          default(1), not null
#  paid             :boolean          default(FALSE), not null
#  installable_type :string           not null
#  installable_id   :bigint           not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#
require 'rails_helper'

RSpec.describe Installment, type: :model do
  let(:card_transaction) { FactoryBot.create(:card_transaction, :random, installments_count: 1) }
  let(:money_transaction) { FactoryBot.create(:money_transaction, :random, installments_count: 1) }

  # validate paid inclusion, etc

  shared_examples 'installments cop' do
    it 'creates the expected amount of installments' do
      expect(card_transaction.installments_count).to eq card_transaction.installments.count
      expect(money_transaction.installments_count).to eq money_transaction.installments.count
    end

    it 'applies the right relationship to the transaction' do
      card_transaction.installments.each do |installment|
        expect(installment.installable_id).to eq card_transaction.id
        expect(installment.installable_type).to eq card_transaction.class.name
      end

      money_transaction.installments.each do |installment|
        expect(installment.installable_id).to eq money_transaction.id
        expect(installment.installable_type).to eq money_transaction.class.name
      end
    end

    it 'sums the installments correctly' do
      expect(card_transaction.installments.sum(:price).round(2)).to eq card_transaction.price
      expect(money_transaction.installments.sum(:price).round(2)).to eq money_transaction.price
    end
  end

  describe '[ business logic ]' do
    context '( when installments_count is 1 )' do
      include_examples 'installments cop'
    end

    context '( when installments_count is 2 )' do
      before do
        card_transaction.update(installments_count: 2)
        money_transaction.update(installments_count: 2)
      end

      include_examples 'installments cop'
    end

    context '( when installments_count is 3 )' do
      before do
        card_transaction.update(installments_count: 3)
        money_transaction.update(installments_count: 3)
      end

      include_examples 'installments cop'
    end
  end
end
