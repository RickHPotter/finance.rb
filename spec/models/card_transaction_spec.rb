# frozen_string_literal: true

require "rails_helper"

RSpec.describe CardTransaction, type: :model do
  let(:user_card) { create(:user_card, :random) }
  let(:card_transaction) { build(:card_transaction, :random, user_card:) }

  def create_supporting_card_transaction(user:, user_card:, invoice_cash_transaction:) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
    transaction = create(
      :card_transaction,
      user:,
      context: user.main_context,
      user_card:,
      description: "Supporting invoice amount",
      price: -1000,
      date: Date.new(2026, 3, 12),
      month: 3,
      year: 2026
    )
    original_cash_transaction = transaction.card_installments.first.cash_transaction

    transaction.card_installments.first.update_columns(
      price: -1000,
      starting_price: -1000,
      date: Date.new(2026, 3, 12),
      month: 3,
      year: 2026,
      paid: false,
      cash_transaction_id: invoice_cash_transaction.id
    )
    transaction.update_columns(price: -1000, starting_price: -1000, date: Date.new(2026, 3, 12), month: 3, year: 2026, card_installments_count: 1)

    invoice_cash_transaction.cash_installments.delete_all
    invoice_cash_transaction.cash_installments.create!(
      number: 1,
      price: -1000,
      starting_price: -1000,
      date: invoice_cash_transaction.date,
      month: invoice_cash_transaction.month,
      year: invoice_cash_transaction.year,
      paid: true
    )
    invoice_cash_transaction.cash_installments.create!(
      number: 2,
      price: -1000,
      starting_price: -1000,
      date: invoice_cash_transaction.date + 1.day,
      month: invoice_cash_transaction.month,
      year: invoice_cash_transaction.year,
      paid: false
    )
    invoice_cash_transaction.update_columns(price: -2000, paid: false, cash_installments_count: 2)
    invoice_cash_transaction.cash_installments.find_by!(number: 1).update_columns(price: -1000, starting_price: -1000, paid: true)
    invoice_cash_transaction.cash_installments.find_by!(number: 2).update_columns(price: -1000, starting_price: -1000, paid: false)

    if original_cash_transaction.present? && original_cash_transaction.id != invoice_cash_transaction.id
      Installment.where(cash_transaction_id: original_cash_transaction.id).delete_all
      CashTransaction.where(id: original_cash_transaction.id).delete_all
    end

    transaction.reload
  end

  def create_card_transaction_with_history(user:, user_card:, installments_attributes:, **attrs)
    transaction = create(:card_transaction, user:, context: user.main_context, user_card:, **attrs)
    stale_cash_transaction_ids = transaction.card_installments.pluck(:cash_transaction_id).compact
    transaction.card_installments.delete_all
    Installment.where(cash_transaction_id: stale_cash_transaction_ids).delete_all
    CashTransaction.where(id: stale_cash_transaction_ids).delete_all

    installments_attributes.each do |installment_attrs|
      transaction.card_installments.create!(installment_attrs.merge(paid: false))
    end

    transaction.card_installments.order(:number).zip(installments_attributes).each do |installment, installment_attrs|
      installment.update_columns(
        price: installment_attrs[:price],
        date: installment_attrs[:date],
        month: installment_attrs[:month],
        year: installment_attrs[:year],
        paid: installment_attrs[:paid]
      )
    end

    transaction.update_column(:card_installments_count, transaction.card_installments.count)
    transaction.reload
  end

  describe "[ activerecord validations ]" do
    context "( presence, uniqueness, etc )" do
      it "is valid with valid attributes" do
        expect(card_transaction).to be_valid
      end

      %i[description date price card_installments_count].each do |attribute|
        it { should validate_presence_of(attribute) }
      end
    end

    context "( associations )" do
      bt_models = %i[user user_card]
      bto_models = %i[advance_cash_transaction reference_transactable subscription]
      hm_models = %i[categories category_transactions entities entity_transactions card_installments]
      na_models = %i[category_transactions entity_transactions card_installments]

      bt_models.each { |model| it { should belong_to(model) } }
      bto_models.each { |model| it { should belong_to(model).optional } }
      hm_models.each { |model| it { should have_many(model) } }
      na_models.each { |model| it { should accept_nested_attributes_for(model) } }

      it "belongs to context" do
        association = described_class.reflect_on_association(:context)

        expect(association.macro).to eq(:belongs_to)
        expect(association.options[:optional]).to be(false)
      end
    end
  end

  describe "[ business logic ]" do
    it "defaults context to the user's main context" do
      transaction = described_class.new(
        user: card_transaction.user,
        user_card: card_transaction.user_card,
        description: "Context default",
        date: Date.new(2026, 3, 23),
        price: -100,
        month: 4,
        year: 2026,
        card_installments_attributes: [
          { number: 1, price: -100, date: Date.new(2026, 3, 23), month: 4, year: 2026 }
        ]
      )

      transaction.valid?

      expect(transaction.context).to eq(card_transaction.user.main_context)
    end

    it "can be destroyed when persisted" do
      card_transaction.save!

      expect(card_transaction.can_be_destroyed?).to be(true)
    end

    it "derives paid-history safety predicates from its installments" do
      user = create(:user)
      user_card = create(:user_card, user:)
      transaction = create_card_transaction_with_history(
        user:,
        user_card:,
        description: "Safety boundary",
        date: Date.new(2026, 3, 10),
        price: -3000,
        month: 4,
        year: 2026,
        installments_attributes: [
          { number: 1, price: -1000, date: Date.new(2026, 3, 10), month: 3, year: 2026, paid: true },
          { number: 2, price: -1000, date: Date.new(2026, 4, 10), month: 4, year: 2026, paid: false },
          { number: 3, price: -1000, date: Date.new(2026, 5, 10), month: 5, year: 2026, paid: false }
        ]
      )

      expect(transaction).to be_paid_history
      expect(transaction).to be_partially_paid
      expect(transaction.latest_paid_installment_date).to eq(Date.new(2026, 3, 10))
      expect(transaction.can_edit_unpaid_future_installments?([ Date.new(2026, 4, 10), Date.new(2026, 5, 10) ])).to be(true)
      expect(transaction.can_edit_unpaid_future_installments?([ Date.new(2026, 3, 10) ])).to be(false)
      expect(transaction.can_change_allocation?).to be(false)
      expect(transaction.can_destroy_with_history?).to be(false)
    end

    it "blocks category allocation changes once paid history exists" do
      user = create(:user)
      user_card = create(:user_card, user:)
      category = create(:category, user:, category_name: "FOOD")
      replacement_category = create(:category, user:, category_name: "TRANSPORT")
      transaction = create_card_transaction_with_history(
        user:,
        user_card:,
        description: "Locked allocation",
        date: Date.new(2026, 3, 10),
        price: -3000,
        month: 4,
        year: 2026,
        category_transactions_attributes: [
          { category_id: category.id }
        ],
        installments_attributes: [
          { number: 1, price: -1000, date: Date.new(2026, 3, 10), month: 3, year: 2026, paid: true },
          { number: 2, price: -1000, date: Date.new(2026, 4, 10), month: 4, year: 2026, paid: false },
          { number: 3, price: -1000, date: Date.new(2026, 5, 10), month: 5, year: 2026, paid: false }
        ]
      )

      transaction.categories = [ replacement_category ]

      expect(transaction).to be_invalid
      expect(transaction.errors[:base]).to include(I18n.t("activerecord.errors.models.card_transaction.attributes.base.allocation_locked_after_payment"))
    end

    it "allows unpaid future installment edits after the latest paid boundary" do
      user = create(:user)
      user_card = create(:user_card, user:)
      transaction = create_card_transaction_with_history(
        user:,
        user_card:,
        description: "Future edits",
        date: Date.new(2026, 3, 10),
        price: -3000,
        month: 4,
        year: 2026,
        installments_attributes: [
          { number: 1, price: -1000, date: Date.new(2026, 3, 10), month: 3, year: 2026, paid: true },
          { number: 2, price: -1000, date: Date.new(2026, 4, 10), month: 4, year: 2026, paid: false },
          { number: 3, price: -1000, date: Date.new(2026, 5, 10), month: 5, year: 2026, paid: false }
        ]
      )

      second_installment = transaction.card_installments.find_by!(number: 2)
      third_installment = transaction.card_installments.find_by!(number: 3)

      transaction.card_installments_attributes = [
        { id: second_installment.id, number: 2, price: second_installment.price, date: Date.new(2026, 4, 15), month: 4, year: 2026, paid: false },
        { id: third_installment.id, number: 3, price: third_installment.price, date: Date.new(2026, 5, 15), month: 5, year: 2026, paid: false }
      ]

      expect(transaction).to be_valid
    end

    it "blocks unpaid installment edits that cross the paid boundary" do
      user = create(:user)
      user_card = create(:user_card, user:)
      transaction = create_card_transaction_with_history(
        user:,
        user_card:,
        description: "Unsafe future edit",
        date: Date.new(2026, 3, 10),
        price: -3000,
        month: 4,
        year: 2026,
        installments_attributes: [
          { number: 1, price: -1000, date: Date.new(2026, 3, 10), month: 3, year: 2026, paid: true },
          { number: 2, price: -1000, date: Date.new(2026, 4, 10), month: 4, year: 2026, paid: false },
          { number: 3, price: -1000, date: Date.new(2026, 5, 10), month: 5, year: 2026, paid: false }
        ]
      )

      second_installment = transaction.card_installments.find_by!(number: 2)

      transaction.card_installments_attributes = [
        { id: second_installment.id, number: 2, price: second_installment.price, date: Date.new(2026, 3, 10), month: 3, year: 2026, paid: false }
      ]

      expect(transaction).to be_invalid
      expect(transaction.errors[:base]).to include(I18n.t("activerecord.errors.models.card_transaction.attributes.base.paid_history_locked"))
    end

    it "blocks parent price changes once paid history exists" do
      user = create(:user)
      user_card = create(:user_card, user:)
      transaction = create_card_transaction_with_history(
        user:,
        user_card:,
        description: "Locked parent fields",
        date: Date.new(2026, 3, 10),
        price: -3000,
        month: 4,
        year: 2026,
        installments_attributes: [
          { number: 1, price: -1000, date: Date.new(2026, 3, 10), month: 3, year: 2026, paid: true },
          { number: 2, price: -1000, date: Date.new(2026, 4, 10), month: 4, year: 2026, paid: false },
          { number: 3, price: -1000, date: Date.new(2026, 5, 10), month: 5, year: 2026, paid: false }
        ]
      )

      transaction.price = -3500

      expect(transaction).to be_invalid
      expect(transaction.errors[:base]).to include(I18n.t("activerecord.errors.models.card_transaction.attributes.base.paid_history_locked"))
    end

    it "allows a confirmed paid date correction when the ref month year stays unchanged" do
      user = create(:user)
      user_card = create(:user_card, user:)
      transaction = create_card_transaction_with_history(
        user:,
        user_card:,
        description: "Same cycle correction",
        date: Date.new(2026, 3, 10),
        price: -3000,
        month: 4,
        year: 2026,
        installments_attributes: [
          { number: 1, price: -1000, date: Date.new(2026, 3, 10), month: 3, year: 2026, paid: true },
          { number: 2, price: -1000, date: Date.new(2026, 4, 10), month: 4, year: 2026, paid: false },
          { number: 3, price: -1000, date: Date.new(2026, 5, 10), month: 5, year: 2026, paid: false }
        ]
      )

      first_installment = transaction.card_installments.find_by!(number: 1)
      transaction.historical_correction_confirmation = true
      transaction.card_installments_attributes = [
        { id: first_installment.id, number: 1, price: first_installment.price, date: Date.new(2026, 3, 25), month: 3, year: 2026, paid: true }
      ]

      expect(transaction).to be_valid
    end

    it "allows a confirmed paid amount correction on a normal card transaction" do
      user = create(:user)
      user_card = create(:user_card, user:)
      transaction = create_card_transaction_with_history(
        user:,
        user_card:,
        description: "Paid amount correction",
        date: Date.new(2026, 3, 10),
        price: -3000,
        month: 4,
        year: 2026,
        installments_attributes: [
          { number: 1, price: -1000, date: Date.new(2026, 3, 10), month: 3, year: 2026, paid: true },
          { number: 2, price: -1000, date: Date.new(2026, 4, 10), month: 4, year: 2026, paid: false },
          { number: 3, price: -1000, date: Date.new(2026, 5, 10), month: 5, year: 2026, paid: false }
        ]
      )

      first_installment = transaction.card_installments.find_by!(number: 1)
      second_installment = transaction.card_installments.find_by!(number: 2)
      third_installment = transaction.card_installments.find_by!(number: 3)

      transaction.historical_correction_confirmation = true
      transaction.price = -3500
      transaction.card_installments_attributes = [
        { id: first_installment.id, number: 1, price: -1500, date: first_installment.date, month: first_installment.month, year: first_installment.year, paid: true },
        { id: second_installment.id, number: 2, price: -1000, date: second_installment.date, month: second_installment.month, year: second_installment.year,
          paid: false },
        { id: third_installment.id, number: 3, price: -1000, date: third_installment.date, month: third_installment.month, year: third_installment.year, paid: false }
      ]

      expect(transaction).to be_valid
    end

    it "blocks destruction when paid history exists" do
      user = create(:user)
      user_card = create(:user_card, user:)
      transaction = create_card_transaction_with_history(
        user:,
        user_card:,
        description: "Locked destroy",
        date: Date.new(2026, 3, 10),
        price: -2000,
        month: 4,
        year: 2026,
        installments_attributes: [
          { number: 1, price: -1000, date: Date.new(2026, 3, 10), month: 3, year: 2026, paid: true },
          { number: 2, price: -1000, date: Date.new(2026, 4, 10), month: 4, year: 2026, paid: false }
        ]
      )

      expect(transaction.destroy).to be(false)
      expect(transaction.errors[:base]).to include(I18n.t("activerecord.errors.models.card_transaction.attributes.base.destroy_locked_after_payment"))
    end

    it "allows confirmed destruction when paid history exists and the cycle remains covered" do
      user = create(:user)
      user_card = create(:user_card, user:)
      transaction = create_card_transaction_with_history(
        user:,
        user_card:,
        description: "Confirmed destroy",
        date: Date.new(2026, 3, 10),
        price: -2000,
        month: 4,
        year: 2026,
        installments_attributes: [
          { number: 1, price: -1000, date: Date.new(2026, 3, 10), month: 3, year: 2026, paid: true },
          { number: 2, price: -1000, date: Date.new(2026, 4, 10), month: 4, year: 2026, paid: false }
        ]
      )
      create_supporting_card_transaction(
        user:,
        user_card:,
        invoice_cash_transaction: transaction.card_installments.find_by!(number: 1).cash_transaction
      )

      transaction.historical_correction_confirmation = true

      transaction.destroy

      expect(transaction).to be_destroyed
    end
  end
end

# == Schema Information
#
# Table name: card_transactions
# Database name: primary
#
#  id                          :bigint           not null, primary key
#  card_installments_count     :integer          default(0), not null
#  comment                     :text
#  date                        :datetime         not null
#  description                 :string           not null, indexed
#  imported                    :boolean          default(FALSE)
#  month                       :integer          not null
#  paid                        :boolean          default(FALSE)
#  price                       :integer          not null, indexed
#  reference_transactable_type :string           indexed => [reference_transactable_id], uniquely indexed => [reference_transactable_id]
#  starting_price              :integer          not null
#  year                        :integer          not null
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#  advance_cash_transaction_id :bigint           indexed
#  context_id                  :bigint           not null, indexed
#  reference_transactable_id   :bigint           indexed => [reference_transactable_type], uniquely indexed => [reference_transactable_type]
#  subscription_id             :bigint           indexed
#  user_card_id                :bigint           not null, indexed
#  user_id                     :bigint           not null, indexed
#
# Indexes
#
#  idx_card_transactions_description_trgm                  (description) USING gin
#  idx_card_transactions_price                             (price)
#  index_card_transactions_on_advance_cash_transaction_id  (advance_cash_transaction_id)
#  index_card_transactions_on_context_id                   (context_id)
#  index_card_transactions_on_reference_transactable       (reference_transactable_type,reference_transactable_id)
#  index_card_transactions_on_subscription_id              (subscription_id)
#  index_card_transactions_on_user_card_id                 (user_card_id)
#  index_card_transactions_on_user_id                      (user_id)
#  index_reference_transactable_on_card_composite_key      (reference_transactable_type,reference_transactable_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (advance_cash_transaction_id => cash_transactions.id)
#  fk_rails_...  (context_id => contexts.id)
#  fk_rails_...  (subscription_id => finance_subscriptions.id)
#  fk_rails_...  (user_card_id => user_cards.id)
#  fk_rails_...  (user_id => users.id)
#
