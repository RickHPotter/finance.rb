# frozen_string_literal: true

# == Schema Information
#
# Table name: investments
#
#  id                   :integer          not null, primary key
#  price                :decimal(, )      not null
#  date                 :date             not null
#  month                :integer          not null
#  year                 :integer          not null
#  user_id              :integer          not null
#  category_id          :integer          not null
#  user_bank_account_id :integer          not null
#  money_transaction_id :integer          not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#
require 'awesome_print'
require 'rails_helper'
include FactoryHelper

RSpec.describe Investment, type: :model do
  user = User.last
  category = FactoryHelper.custom_create(model: :category, traits: [:random], reference: { user: })
  user_bank_account = FactoryHelper.custom_create(model: :user_bank_account, traits: [:random], reference: { user: })
  options = { user:, category:, user_bank_account: }

  let(:investment) { FactoryBot.create(:investment, :random) }

  let(:inv1) { FactoryBot.create(:investment, :random, options.merge(date: Date.new(2023, 7, 1))) }
  let!(:inv2) { FactoryBot.create(:investment, :random, options.merge(date: Date.new(2023, 7, 2))) }
  let!(:inv3) { FactoryBot.create(:investment, :random, options.merge(date: Date.new(2023, 7, 3))) }
  let(:money_transaction) { inv1.money_transaction }

  shared_examples 'investment cop' do
    it 'sums the investments correctly' do
      ap money_transaction.investments.pluck(:id, :price)
      expect(money_transaction.price).to be_within(0.01).of money_transaction.investments.sum(:price)
    end

    it 'generates the comment that references every investments day' do
      expect(money_transaction.mt_comment).to include(money_transaction.investments.order(:date).map(&:day).join(', '))
    end
  end

  describe '[ manipulating investments ]' do
    context 'when new investments are created' do
      it 'attachs the same money_transaction for all investments' do
        money_transaction.reload
        expect(inv1.money_transaction).to eq inv2.money_transaction
        expect(inv1.money_transaction).to eq inv3.money_transaction
      end

      # FIXME: these dont work, lol
      include_examples 'investment cop'
    end

    context 'when existing investments are updated' do
      it 'updates the investments' do
        [inv1, inv2, inv3].each do |inv|
          inv.update(price: Faker::Number.decimal(l_digits: rand(1..3)))
          money_transaction.reload
        end
      end

      include_examples 'investment cop'
    end

    context 'when most investments are deleted' do
      it 'deletes two investment and only one is found in money_transaction.investments' do
        [inv1, inv2].each(&:destroy)

        expect(money_transaction.investments).not_to include(inv1)
        expect(money_transaction.investments).not_to include(inv2)
        expect(money_transaction.investments).to include(inv3)
      end

      include_examples 'investment cop'
    end

    context 'when all investments are deleted' do
      it 'deletes all elements and money_transaction ceases to exist' do
        [inv1, inv2, inv3].each(&:destroy)
        # TODO: check if MoneyTransaction was purged
      end

      include_examples 'investment cop'
    end
  end

  describe 'presence validations' do
    it 'is valid with valid attributes' do
      expect(investment).to be_valid
    end

    %i[price date].each do |attribute|
      it_behaves_like 'validate_nil', :investment, attribute
      it_behaves_like 'validate_blank', :investment, attribute
    end
  end

  describe 'associations' do
    %i[user user_bank_account category money_transaction].each do |model|
      it "belongs_to #{model}" do
        expect(investment).to respond_to model
      end
    end
  end

  describe 'public methods' do
    it 'returns a formatted date' do
      investment.update(date: Date.new(2023, 12))
      expect(investment.month_year).to eq 'DEC <23>'
    end
  end
end
