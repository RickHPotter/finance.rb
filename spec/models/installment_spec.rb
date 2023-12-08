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
  shared_examples 'it creates the right amount of installments' do |installments_no|
    # FIXME: this should be a let and before the shared_examples
    card_transaction = FactoryBot.create(:card_transaction, :random, installments_count: installments_no)

    it 'creates the expected amount of installments' do
      expect(card_transaction.installments.count).to eq installments_no
    end

    it 'applies the right relationship to the installments' do
      card_transaction.installments.each do |installment|
        expect(installment.installable_id).to eq card_transaction.id
        expect(installment.installable_type).to eq 'CardTransaction'
      end
    end

    it 'sums the installments correctly' do
      expect(card_transaction.installments.sum(:price)).to eq card_transaction.price
    end
  end

  context 'when installments_count is 1' do
    include_examples 'it creates the right amount of installments', 1
  end

  context 'when installments_count is 2' do
    include_examples 'it creates the right amount of installments', 2
  end

  context 'when installments_count is 3' do
    include_examples 'it creates the right amount of installments', 3
  end
end
