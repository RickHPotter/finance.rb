# frozen_string_literal: true

require "rails_helper"

RSpec.describe Investment, type: :model do
  include FactoryHelper

  let(:subject) { create(:investment, :random, date: Date.new(2023, 7, 1)) }
  let(:cash_transaction) { subject.cash_transaction }
  let!(:investments) do
    build_list(:investment, 3, :random, user: subject.user, user_bank_account: subject.user_bank_account, date: subject.date) do |inv, i|
      inv.save(date: subject.date + i + 1)
    end
  end

  shared_examples "investment cop" do
    it "sums the investments correctly" do
      expect(cash_transaction.price).to be_within(0.01).of cash_transaction.investments.sum(:price).round(2)
    end

    it "generates the comment that references every investments day" do
      expect(cash_transaction.comment).to include(cash_transaction.investments.order(:date).map(&:day).join(", "))
    end
  end

  describe "[ activerecord validations ]" do
    context "( presence, uniqueness, etc )" do
      it "is valid with valid attributes" do
        expect(subject).to be_valid
      end

      %i[price date].each do |attribute|
        it { should validate_presence_of(attribute) }
      end
    end

    context "( associations )" do
      ob_models = %i[cash_transaction]
      bt_models = %i[user user_bank_account]
      hm_models = %i[category_transactions categories]
      na_models = %i[category_transactions]

      ob_models.each { |model| it { should belong_to(model).optional } }
      bt_models.each { |model| it { should belong_to(model) } }
      hm_models.each { |model| it { should have_many(model) } }
      na_models.each { |model| it { should accept_nested_attributes_for(model) } }
    end
  end

  # FIXME: move this to request spec when the view is ready
  describe "[ business logic ]" do
    context "( when new investments are created )" do
      before { cash_transaction.reload }

      it "applies the right relationship to the cash_transaction" do
        2.times do |i|
          expect(investments[i].cash_transaction).to eq investments[i + 1].cash_transaction
        end
      end

      include_examples "investment cop"
    end

    context "( when existing investments are updated )" do
      before do
        investments.each do |inv|
          inv.update(price: Faker::Number.number(digits: rand(3..4)))
        end

        cash_transaction.reload
      end

      include_examples "investment cop"
    end

    context "( when most investments are deleted )" do
      before do
        investments.each(&:destroy)
        cash_transaction.reload
      end

      it "finds in cash_transaction.investments only the third element" do
        investments.each do |inv|
          expect(cash_transaction.investments).not_to include(inv)
        end
        expect(cash_transaction.investments).to include(subject)
      end

      include_examples "investment cop"
    end

    context "( when all investments are deleted )" do
      before { [ subject, *investments ].each(&:destroy) }

      it "deletes all investments" do
        [ subject, *investments ].each do |inv|
          expect(inv).to be_destroyed
        end
      end

      it "deletes the corresponding cash_transaction" do
        expect(CashTransaction.find_by(id: cash_transaction.id)).to be_nil
      end
    end

    context "( when the user_bank_account is changed )" do
      before { cash_transaction.reload }

      it "creates or uses another cash_transaction that fits the FK change" do
        expect(subject.cash_transaction).to eq cash_transaction
        expect(subject.cash_transaction.investments.count).to eq(investments.size + 1)
        expect(subject.cash_transaction.price).to be_within(0.01).of([ subject, *investments ].sum(&:price).round(2))

        subject.update(user_bank_account: random_custom_create(:user_bank_account, reference: { user: subject.user }))
        investments.first.cash_transaction.reload

        expect(subject.cash_transaction).to_not eq cash_transaction
        expect(subject.cash_transaction.investments.count).to eq(1)
        expect(investments.first.cash_transaction.investments.count).to eq(investments.size)
        expect(investments.first.cash_transaction.price).to be_within(0.01).of(investments.sum(&:price).round(2))
      end
    end
  end
end

# == Schema Information
#
# Table name: investments
#
#  id                   :bigint           not null, primary key
#  date                 :date             not null
#  description          :string
#  month                :integer          not null
#  price                :integer          not null
#  year                 :integer          not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  cash_transaction_id  :bigint           indexed
#  user_bank_account_id :bigint           not null, indexed
#  user_id              :bigint           not null, indexed
#
# Indexes
#
#  index_investments_on_cash_transaction_id   (cash_transaction_id)
#  index_investments_on_user_bank_account_id  (user_bank_account_id)
#  index_investments_on_user_id               (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (cash_transaction_id => cash_transactions.id)
#  fk_rails_...  (user_bank_account_id => user_bank_accounts.id)
#  fk_rails_...  (user_id => users.id)
#
