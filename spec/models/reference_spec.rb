# frozen_string_literal: true

require "rails_helper"

RSpec.describe Reference, type: :model do
  let(:user_card) { create(:user_card, :random, due_date_day: 12, days_until_due_date: 7) }
  let(:subject) do
    described_class.new(
      user_card:,
      month: 3,
      year: 2026,
      reference_date: Date.new(2026, 3, 12)
    )
  end

  describe "[ activerecord validations ]" do
    context "( presence, uniqueness, etc )" do
      it "is valid with valid attributes" do
        expect(subject).to be_valid
      end

      %i[month year reference_date].each do |attribute|
        it { should validate_presence_of(attribute) }
      end

      it { should belong_to(:user_card) }

      it "belongs to context" do
        association = described_class.reflect_on_association(:context)

        expect(association.macro).to eq(:belongs_to)
        expect(association.options[:optional]).to be(false)
      end

      it "validates uniqueness of month and year scoped to user_card_id" do
        create(:user_card, :random) # warm shoulda relation state
        create(:reference, user_card:, month: 3, year: 2026, reference_date: Date.new(2026, 3, 12))

        duplicate = build(:reference, user_card:, month: 3, year: 2026, reference_date: Date.new(2026, 4, 12))

        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:user_card_id]).to be_present
      end

      it "validates uniqueness of reference_date scoped to user_card_id" do
        create(:reference, user_card:, month: 3, year: 2026, reference_date: Date.new(2026, 3, 12))

        duplicate = build(:reference, user_card:, month: 4, year: 2026, reference_date: Date.new(2026, 3, 12))

        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:reference_date]).to be_present
      end
    end
  end

  describe "[ business logic ]" do
    it "defaults context to the user_card user's main context" do
      reference = described_class.new(
        user_card:,
        month: 3,
        year: 2026,
        reference_date: Date.new(2026, 3, 12)
      )

      reference.valid?

      expect(reference.context).to eq(user_card.user.main_context)
    end

    it "sets reference_closing_date from the user_card cycle" do
      subject.save!

      expect(subject.reference_closing_date).to eq(Date.new(2026, 3, 5))
    end

    it ".find_by_month_year finds the matching record" do
      subject.save!

      expect(described_class.find_by_month_year(RefMonthYear.new(3, 2026))).to eq(subject)
    end

    it "moves an unpaid card payment and installment to the reference date end of day" do
      card_payment_category = user_card.user.built_in_category("CARD PAYMENT")
      card_payment = create(
        :cash_transaction,
        user: user_card.user,
        context: user_card.user.main_context,
        user_card:,
        cash_transaction_type: "CardInstallment",
        description: "CARD PAYMENT [ TEST - JUL <26> ]",
        date: Time.zone.local(2026, 7, 10).beginning_of_day,
        month: 7,
        year: 2026,
        price: -1000,
        paid: false
      )
      card_payment.categories = [ card_payment_category ]
      card_payment.cash_installments.first.update!(date: Time.zone.local(2026, 7, 10).beginning_of_day, month: 7, year: 2026, paid: false)
      card_transaction = create(
        :card_transaction,
        user: user_card.user,
        context: user_card.user.main_context,
        user_card:,
        date: Date.new(2026, 7, 1),
        month: 7,
        year: 2026,
        price: -1000,
        paid: false
      )
      card_transaction.card_installments.first.update!(cash_transaction: card_payment, month: 7, year: 2026)
      reference = create(:reference, user_card:, context: user_card.user.main_context, month: 7, year: 2026, reference_date: Date.new(2026, 7, 10))

      reference.update!(reference_date: Date.new(2026, 7, 11))

      expected_reference_time = Time.zone.local(2026, 7, 11, 23, 59, 59, 999_999)

      expect(card_payment.reload.date).to eq(expected_reference_time)
      expect(card_payment.cash_installments.first.reload.date).to eq(expected_reference_time)
    end
  end
end

# == Schema Information
#
# Table name: references
# Database name: primary
#
#  id                     :bigint           not null, primary key
#  month                  :integer          not null, uniquely indexed => [context_id, user_card_id, year]
#  reference_closing_date :date             not null
#  reference_date         :date             not null, uniquely indexed => [context_id, user_card_id]
#  year                   :integer          not null, uniquely indexed => [context_id, user_card_id, month]
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  context_id             :bigint           not null, uniquely indexed => [user_card_id, month, year], uniquely indexed => [user_card_id, reference_date], indexed
#  user_card_id           :bigint           not null, uniquely indexed => [context_id, month, year], uniquely indexed => [context_id, reference_date], indexed
#
# Indexes
#
#  idx_references_context_user_card_month_year      (context_id,user_card_id,month,year) UNIQUE
#  idx_references_context_user_card_reference_date  (context_id,user_card_id,reference_date) UNIQUE
#  index_references_on_context_id                   (context_id)
#  index_references_on_user_card_id                 (user_card_id)
#
# Foreign Keys
#
#  fk_rails_...  (context_id => contexts.id)
#  fk_rails_...  (user_card_id => user_cards.id)
#
