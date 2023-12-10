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
require 'rails_helper'

include FactoryHelper

RSpec.describe Investment, type: :model do
  user = FactoryBot.create(:user, :random)
  category = FactoryHelper.custom_create(model: :category, traits: [:random], reference: { user: })
  user_bank_account = FactoryHelper.custom_create(model: :user_bank_account, traits: [:random], reference: { user: })
  options = { user:, category:, user_bank_account: }

  let(:investment) { FactoryBot.create(:investment, :random) }

  let!(:inv1) { FactoryBot.create(:investment, :random, options.merge(date: Date.new(2023, 7, 1))) }
  let!(:inv2) { FactoryBot.create(:investment, :random, options.merge(date: Date.new(2023, 7, 2))) }
  let!(:inv3) { FactoryBot.create(:investment, :random, options.merge(date: Date.new(2023, 7, 3))) }
  let!(:money_transaction) { inv1.money_transaction }

  shared_examples 'investment cop' do
    it 'sums the investments correctly' do
      expect(money_transaction.price).to be_within(0.01).of money_transaction.investments.sum(:price)
    end

    it 'generates the comment that references every investments day' do
      expect(money_transaction.mt_comment).to include(money_transaction.investments.order(:date).map(&:day).join(', '))
    end
  end

  describe '[ activerecord validations ]' do
    context '( presence, uniquness, etc )' do
      it 'is valid with valid attributes' do
        expect(investment).to be_valid
      end

      %i[price date].each do |attribute|
        it_behaves_like 'validate_nil', :investment, attribute
        it_behaves_like 'validate_blank', :investment, attribute
      end
    end

    context '( associations )' do
      %i[user user_bank_account category money_transaction].each do |model|
        it "belongs_to #{model}" do
          expect(investment).to respond_to model
        end
      end
    end

    context '( public methods )' do
      it 'returns a formatted date' do
        investment.update(date: Date.new(2023, 12))
        expect(investment.month_year).to eq 'DEC <23>'
      end
    end
  end

  describe '[ business logic ]' do
    context '( when new investments are created )' do
      before { money_transaction.reload }

      it 'applies the right relationship to the money_transaction' do
        expect(inv1.money_transaction).to eq inv2.money_transaction
        expect(inv1.money_transaction).to eq inv3.money_transaction
      end

      include_examples 'investment cop'
    end

    context '( when existing investments are updated )' do
      before do
        [inv1, inv2].each do |inv|
          inv.update(price: Faker::Number.decimal(l_digits: rand(0..1)))
        end
        money_transaction.reload
      end

      include_examples 'investment cop'
    end

    context '( when most investments are deleted )' do
      before do
        [inv1, inv2].each(&:destroy)
        money_transaction.reload
      end

      it 'finds in money_transaction.investments only the third element' do
        expect(money_transaction.investments).not_to include(inv1)
        expect(money_transaction.investments).not_to include(inv2)
        expect(money_transaction.investments).to include(inv3)
      end

      include_examples 'investment cop'
    end

    context '( when all investments are deleted )' do
      before { [inv1, inv2, inv3].each(&:destroy)  }

      it 'deletes all investments' do
        %i[inv1 inv2 inv3].each do |model|
          expect(public_send(model)).to be_destroyed
        end
      end

      it 'deletes the corresponding money_transaction' do
        expect(MoneyTransaction.find_by(id: money_transaction.id)).to be_nil
      end
    end

    # TODO: Test when one of the FKS are changed (should create/use another money_transaction)
  end
end
