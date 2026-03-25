# frozen_string_literal: true

require "rails_helper"

RSpec.describe CardTransaction, type: :model do
  let(:user_card) { create(:user_card, :random) }
  let(:card_transaction) { build(:card_transaction, :random, user_card:) }

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
      transaction = create(
        :card_transaction,
        user:,
        context: user.main_context,
        user_card:,
        description: "Safety boundary",
        date: Date.new(2026, 3, 10),
        price: -3000,
        month: 4,
        year: 2026,
        card_installments_attributes: [
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
