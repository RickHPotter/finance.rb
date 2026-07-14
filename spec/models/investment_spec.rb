# frozen_string_literal: true

require "rails_helper"

RSpec.describe Investment, type: :model do
  include FactoryHelper

  let(:subject) { create(:investment, :random, date: Date.new(2023, 7, 1)) }
  let(:cash_transaction) { subject.cash_transaction }
  let!(:investments) do
    build_list(
      :investment,
      3,
      :random,
      user: subject.user,
      user_bank_account: subject.user_bank_account,
      investment_type: subject.investment_type,
      date: subject.date
    ) do |inv, i|
      inv.save(date: subject.date + i + 1)
    end
  end

  def create_piggy_bank_return(user:, account:, entity:, price: 5_000)
    source = build(
      :cash_transaction,
      user:,
      context: user.main_context,
      user_bank_account: account,
      description: "Monthly reserve",
      price: -price,
      cash_installments: [ build(:cash_installment, number: 1, price: -price, date: Time.zone.now) ],
      category_transactions: [ CategoryTransaction.new(category: user.built_in_category("PIGGY BANK")) ],
      entity_transactions: [ EntityTransaction.new(entity:, price: 0, price_to_be_returned: 0, is_payer: false) ],
      piggy_bank: PiggyBank.new(return_price: price, return_date: 3.months.from_now)
    )
    source.save!
    source.piggy_bank.return_cash_transaction
  end

  shared_examples "investment cop" do
    it "sums the investments correctly" do
      expect(cash_transaction.price).to eq cash_transaction.investments.sum(:price)
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

      %i[price date description].each do |attribute|
        it { should validate_presence_of(attribute) }
      end
    end

    context "( associations )" do
      ob_models = %i[cash_transaction]
      bt_models = %i[user user_bank_account investment_type]
      hm_models = %i[category_transactions categories]
      na_models = %i[category_transactions]

      ob_models.each { |model| it { should belong_to(model).optional } }
      bt_models.each { |model| it { should belong_to(model) } }
      hm_models.each { |model| it { should have_many(model) } }
      na_models.each { |model| it { should accept_nested_attributes_for(model) } }

      it "belongs to context" do
        association = described_class.reflect_on_association(:context)

        expect(association.macro).to eq(:belongs_to)
        expect(association.options[:optional]).to be(false)
      end
    end
  end

  # TODO: move this to request spec when the view is ready
  describe "[ business logic ]" do
    it "defaults context to the user's main context" do
      investment = described_class.new(
        user: subject.user,
        user_bank_account: subject.user_bank_account,
        investment_type: subject.investment_type,
        description: "Context default",
        price: 100,
        date: Date.new(2026, 3, 23),
        month: 3,
        year: 2026
      )

      investment.valid?

      expect(investment.context).to eq(subject.user.main_context)
    end

    it "allows recording a later investment entry even when the aggregated investment cash transaction is already paid" do
      cash_transaction.cash_installments.first.update!(paid: true)
      cash_transaction.update_column(:paid, true)

      later_entry = build(
        :investment,
        :random,
        user: subject.user,
        context: subject.user.main_context,
        user_bank_account: subject.user_bank_account,
        investment_type: subject.investment_type,
        date: subject.date + 15.days
      )

      expect { later_entry.save! }.to change(Investment, :count).by(1)
      expect(later_entry.cash_transaction).to eq(cash_transaction.reload)
    end

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
        expect(subject.cash_transaction.price).to eq([ subject, *investments ].sum(&:price))

        subject.update(user_bank_account: random_custom_create(:user_bank_account, reference: { user: subject.user }))
        investments.first.cash_transaction.reload

        expect(subject.cash_transaction).to_not eq cash_transaction
        expect(subject.cash_transaction.investments.count).to eq(1)
        expect(investments.first.cash_transaction.investments.count).to eq(investments.size)
        expect(investments.first.cash_transaction.price).to eq investments.sum(&:price)
      end
    end

    context "( with a Piggy Bank return group )" do
      let(:valuation_user) { create(:user, :random) }
      let(:valuation_account) { create(:user_bank_account, :random, user: valuation_user) }
      let(:valuation_type) { create(:investment_type, :random) }
      let(:valuation_entity) { create(:entity, :random, user: valuation_user) }
      let(:piggy_bank_return) do
        create_piggy_bank_return(user: valuation_user, account: valuation_account, entity: valuation_entity)
      end

      def build_valuation(price:)
        build(
          :investment,
          user: valuation_user,
          context: valuation_user.main_context,
          user_bank_account: valuation_account,
          investment_type: valuation_type,
          description: "Recognized Piggy Bank result",
          price:,
          date: Time.zone.today,
          month: Time.zone.today.month,
          year: Time.zone.today.year,
          piggy_bank_return_cash_transaction: piggy_bank_return
        )
      end

      it "applies positive and negative signed deltas without a legacy aggregate transaction" do
        profit = build_valuation(price: 800)
        loss = build_valuation(price: -300)

        expect { profit.save! }.not_to change(CashTransaction, :count)
        expect(piggy_bank_return.reload.price).to eq(5_800)
        expect { loss.save! }.not_to change(CashTransaction, :count)
        expect(piggy_bank_return.reload.price).to eq(5_500)
        expect(profit.cash_transaction).to be_nil
        expect(loss.cash_transaction).to be_nil
      end

      it "rejects a loss that would consume the unpaid return" do
        loss = build_valuation(price: -5_000)

        expect { loss.save }.not_to change(described_class, :count)
        expect(loss.errors.of_kind?(:price, :piggy_bank_projection_non_positive)).to be(true)
        expect(piggy_bank_return.reload.price).to eq(5_000)
      end

      it "preserves paid history and adjusts only the unpaid remainder" do
        paid_installment = piggy_bank_return.cash_installments.first
        paid_installment.update!(price: 1_000, paid: true)
        Logic::Manipulation::CashInstallment.new(paid_installment).split_installment(piggy_bank_return.date, 4_000)

        build_valuation(price: 800).save!

        expect(piggy_bank_return.reload.cash_installments.order(:number).pluck(:price, :paid)).to eq([ [ 1_000, true ], [ 4_800, false ] ])
      end

      it "rejects deleting profit that is already required by paid history" do
        profit = build_valuation(price: 800)
        profit.save!
        piggy_bank_return.cash_installments.first.update!(price: 5_500, paid: true)
        Logic::Manipulation::CashInstallment.new(piggy_bank_return.cash_installments.first).split_installment(piggy_bank_return.date, 300)

        expect(profit.destroy).to be(false)
        expect(profit.errors.of_kind?(:base, :piggy_bank_paid_history_locked)).to be(true)
        expect(piggy_bank_return.reload.price).to eq(5_800)
      end

      it "keeps negative prices invalid for ordinary investments" do
        ordinary = build_valuation(price: -1)
        ordinary.piggy_bank_return_cash_transaction = nil

        expect(ordinary).not_to be_valid
        expect(ordinary.errors.of_kind?(:price, :greater_than)).to be(true)
      end
    end
  end
end

# == Schema Information
#
# Table name: investments
# Database name: primary
#
#  id                                    :bigint           not null, primary key
#  date                                  :datetime         not null
#  description                           :string
#  month                                 :integer          not null
#  price                                 :integer          not null
#  year                                  :integer          not null
#  created_at                            :datetime         not null
#  updated_at                            :datetime         not null
#  cash_transaction_id                   :bigint           indexed
#  context_id                            :bigint           not null, indexed
#  investment_type_id                    :bigint           not null, indexed
#  piggy_bank_return_cash_transaction_id :bigint           indexed
#  user_bank_account_id                  :bigint           not null, indexed
#  user_id                               :bigint           not null, indexed
#
# Indexes
#
#  index_investments_on_cash_transaction_id   (cash_transaction_id)
#  index_investments_on_context_id            (context_id)
#  index_investments_on_investment_type_id    (investment_type_id)
#  index_investments_on_piggy_bank_return_id  (piggy_bank_return_cash_transaction_id)
#  index_investments_on_user_bank_account_id  (user_bank_account_id)
#  index_investments_on_user_id               (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (cash_transaction_id => cash_transactions.id)
#  fk_rails_...  (context_id => contexts.id)
#  fk_rails_...  (investment_type_id => investment_types.id)
#  fk_rails_...  (piggy_bank_return_cash_transaction_id => cash_transactions.id)
#  fk_rails_...  (user_bank_account_id => user_bank_accounts.id)
#  fk_rails_...  (user_id => users.id)
#
