# frozen_string_literal: true

require "rails_helper"

RSpec.describe Exchange, type: :model do
  let(:subject) { build(:exchange, :random) }

  describe "[ activerecord validations ]" do
    context "( presence, uniqueness, etc )" do
      it "is valid with valid attributes" do
        expect(subject).to be_valid
      end

      %i[exchange_type number price].each do |attribute|
        it { should validate_presence_of(attribute) }
      end
    end

    context "( associations )" do
      it { should belong_to(:entity_transaction) }
      it { should belong_to(:cash_transaction).optional }
      it { should define_enum_for(:exchange_type).with_values(non_monetary: 0, monetary: 1) }
    end
  end

  describe "[ business logic ]" do
    it "preserves a persisted timestamp when the minute-only exchange form value is unchanged" do
      exchange = create(:exchange)
      precise_date = Time.zone.local(2026, 4, 24, 23, 59, 59) + 0.999_999
      exchange.update_columns(date: precise_date)
      exchange.reload
      persisted_date = exchange.date

      exchange.date = "2026-04-24T23:59"

      expect(exchange.date).to eq(persisted_date)
      expect(exchange).not_to be_changed
    end

    it "treats paid mirrored return history as a locked projection" do
      user = create(:user)
      card_transaction = create(:card_transaction, user:, context: user.main_context, user_card: create(:user_card, user:))
      entity_transaction = create(:entity_transaction, transactable: card_transaction, entity: create(:entity, user:), is_payer: true, price: -1000,
                                                       price_to_be_returned: -1000)
      exchange_return = create(
        :cash_transaction,
        user:,
        context: user.main_context,
        user_bank_account: create(:user_bank_account, user:, bank: create(:bank, :random)),
        description: "Exchange return",
        price: -1000,
        date: Date.new(2026, 3, 20),
        month: 3,
        year: 2026,
        cash_installments_attributes: [
          { number: 1, price: -1000, date: Date.new(2026, 3, 20), month: 3, year: 2026, paid: true }
        ]
      )
      exchange = build(
        :exchange,
        entity_transaction:,
        cash_transaction: exchange_return,
        exchange_type: :monetary,
        number: 1,
        price: -1000,
        date: Date.new(2026, 3, 20),
        month: 3,
        year: 2026
      )

      expect(exchange.projection_locked?).to be(true)
    end

    it "detects drift when the mirrored return installments no longer match the exchanges" do
      user = create(:user)
      card_transaction = create(:card_transaction, user:, context: user.main_context, user_card: create(:user_card, user:))
      entity_transaction = create(:entity_transaction, transactable: card_transaction, entity: create(:entity, user:), is_payer: true, price: -3000,
                                                       price_to_be_returned: -3000)
      exchange_return = create(
        :cash_transaction,
        user:,
        context: user.main_context,
        user_bank_account: create(:user_bank_account, user:, bank: create(:bank, :random)),
        description: "Exchange return",
        price: -3000,
        date: Date.new(2026, 3, 20),
        month: 3,
        year: 2026,
        cash_installments_attributes: [
          { number: 1, price: -1000, date: Date.new(2026, 3, 20), month: 3, year: 2026, paid: false },
          { number: 2, price: -1000, date: Date.new(2026, 4, 20), month: 4, year: 2026, paid: false }
        ]
      )
      create(:exchange, entity_transaction:, cash_transaction: exchange_return, exchange_type: :monetary, number: 1, price: -1000, date: Date.new(2026, 3, 20),
                        month: 3, year: 2026)
      drifting_exchange = create(:exchange, entity_transaction:, cash_transaction: exchange_return, exchange_type: :monetary, number: 2, price: -1000,
                                            date: Date.new(2026, 4, 20), month: 4, year: 2026)
      drifting_exchange.update_columns(price: -2000)

      expect(drifting_exchange.projection_locked?).to be(false)
      expect(drifting_exchange.mirrored_cash_installments_match?).to be(false)
    end

    it "reads paid state from the mirrored installment, not only from the parent cash transaction" do
      user = create(:user)
      card_transaction = create(:card_transaction, user:, context: user.main_context, user_card: create(:user_card, user:))
      entity_transaction = create(:entity_transaction, transactable: card_transaction, entity: create(:entity, user:), is_payer: true, price: -3000,
                                                       price_to_be_returned: -3000)
      exchange_return = create(
        :cash_transaction,
        user:,
        context: user.main_context,
        user_bank_account: create(:user_bank_account, user:, bank: create(:bank, :random)),
        description: "Exchange return",
        price: -3000,
        date: Date.new(2026, 3, 20),
        month: 3,
        year: 2026,
        cash_installments_attributes: [
          { number: 1, price: -1000, date: Date.new(2026, 3, 20), month: 3, year: 2026, paid: false },
          { number: 2, price: -1000, date: Date.new(2026, 4, 20), month: 4, year: 2026, paid: false }
        ]
      )
      paid_exchange = create(:exchange, entity_transaction:, cash_transaction: exchange_return, exchange_type: :monetary, number: 1, price: -1000,
                                        date: Date.new(2026, 3, 20), month: 3, year: 2026)
      unpaid_exchange = create(:exchange, entity_transaction:, cash_transaction: exchange_return, exchange_type: :monetary, number: 2, price: -1000,
                                          date: Date.new(2026, 4, 20), month: 4, year: 2026)
      exchange_return.cash_installments.find_by!(number: 1).update_columns(paid: true)
      exchange_return.update_column(:paid, false)

      expect(paid_exchange.mirrored_paid?).to be(true)
      expect(unpaid_exchange.mirrored_paid?).to be(false)
    end
  end
end

# == Schema Information
#
# Table name: exchanges
# Database name: primary
#
#  id                    :bigint           not null, primary key
#  bound_type            :string           default("standalone"), not null
#  date                  :datetime         not null
#  exchange_type         :integer          default("non_monetary"), not null
#  exchanges_count       :integer          default(0), not null
#  month                 :integer          not null
#  number                :integer          default(1), not null
#  price                 :integer          not null
#  starting_price        :integer          not null
#  year                  :integer          not null
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  cash_transaction_id   :bigint           indexed
#  entity_transaction_id :bigint           not null, indexed
#
# Indexes
#
#  index_exchanges_on_cash_transaction_id    (cash_transaction_id)
#  index_exchanges_on_entity_transaction_id  (entity_transaction_id)
#
# Foreign Keys
#
#  fk_rails_...  (cash_transaction_id => cash_transactions.id)
#  fk_rails_...  (entity_transaction_id => entity_transactions.id)
#
