# frozen_string_literal: true

require "rails_helper"

RSpec.describe Subscription, type: :model do
  let(:subject) { build(:subscription) }

  describe "[ activerecord validations ]" do
    context "( presence, enums, etc )" do
      it "is valid with valid attributes" do
        expect(subject).to be_valid
      end

      %i[description].each do |attribute|
        it { should validate_presence_of(attribute) }
      end

      it { should define_enum_for(:status).with_values(active: "active", paused: "paused", finished: "finished").backed_by_column_of_type(:string) }
      it { should validate_numericality_of(:price) }
    end

    context "( associations )" do
      it { should belong_to(:user) }
      it { should have_many(:cash_transactions).dependent(:nullify) }
      it { should have_many(:card_transactions).dependent(:nullify) }
      it { should have_many(:category_transactions).dependent(:destroy) }
      it { should have_many(:entity_transactions).dependent(:destroy) }
      it { should accept_nested_attributes_for(:cash_transactions) }
      it { should accept_nested_attributes_for(:card_transactions) }
    end
  end

  describe "[ business logic ]" do
    context "( defaults )" do
      it "defaults to active status on create" do
        subscription = described_class.create!(user: create(:user, :random), description: "Gym membership")

        expect(subscription).to be_active
      end
    end

    context "( lightweight intent model )" do
      it "allows zero price as a starting calculated value" do
        subject.price = 0

        expect(subject).to be_valid
      end

      it "returns all linked transactions ordered by date" do
        subscription = create(:subscription)
        older_cash_transaction = create(:cash_transaction, user: subscription.user, user_bank_account: create(:user_bank_account, :random, user: subscription.user),
                                                           subscription:, date: Date.new(2026, 3, 1), price: 100)
        newer_card_transaction = create(:card_transaction, user: subscription.user, user_card: create(:user_card, :random, user: subscription.user), subscription:,
                                                           date: Date.new(2026, 3, 10), price: -50)

        expect(subscription.transactions).to eq([ older_cash_transaction, newer_card_transaction ])
        expect(subscription.reload.transactions_count).to eq(2)
      end

      it "uses cached transaction counters" do
        subscription = build(:subscription)
        subscription[:cash_transactions_count] = 2
        subscription[:card_transactions_count] = 3

        expect(subscription.transactions_count).to eq(5)
      end

      it "refreshes cached price from linked transactions" do
        subscription = create(:subscription, price: 999)
        create(:cash_transaction, user: subscription.user, user_bank_account: create(:user_bank_account, :random, user: subscription.user), subscription:, price: 200)
        create(:card_transaction, user: subscription.user, user_card: create(:user_card, :random, user: subscription.user), subscription:, price: -75)

        subscription.refresh_price!

        expect(subscription.reload.price).to eq(125)
      end

      it "propagates subscription metadata into linked cash transactions" do
        subscription = build(:subscription, description: "Gym", comment: "Monthly")
        category = create(:category, :random, user: subscription.user)
        entity = create(:entity, :random, user: subscription.user)
        bank_account = create(:user_bank_account, :random, user: subscription.user)

        subscription.categories << category
        subscription.entities << entity
        subscription.cash_transactions.build(user_bank_account: bank_account, date: Date.new(2026, 3, 14), price: -100)

        subscription.valid?

        cash_transaction = subscription.cash_transactions.first

        expect(cash_transaction.description).to eq("Gym")
        expect(cash_transaction.comment).to eq("Monthly")
        expect(cash_transaction.categories.map(&:category_name)).to include(category.category_name, "SUBSCRIPTION")
        expect(cash_transaction.entities).to include(entity)
        expect(cash_transaction.cash_installments_count).to eq(1)
      end

      it "requires a card for linked card transactions" do
        subscription = build(:subscription)
        subscription.card_transactions.build(date: Date.new(2026, 3, 14), price: -100)

        expect(subscription).to be_invalid
        expect(subscription.card_transactions.first.errors[:user_card_id]).to be_present
      end
    end
  end
end

# == Schema Information
#
# Table name: finance_subscriptions
# Database name: primary
#
#  id                      :bigint           not null, primary key
#  card_transactions_count :integer          default(0), not null
#  cash_transactions_count :integer          default(0), not null
#  comment                 :text
#  description             :string           not null
#  price                   :integer          default(0), not null
#  status                  :string           default("active"), not null, indexed
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  user_id                 :bigint           not null, indexed
#
# Indexes
#
#  index_finance_subscriptions_on_status   (status)
#  index_finance_subscriptions_on_user_id  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
