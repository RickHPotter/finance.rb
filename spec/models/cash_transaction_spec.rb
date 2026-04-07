# frozen_string_literal: true

require "rails_helper"

RSpec.describe CashTransaction, type: :model do
  let(:subject) { build(:cash_transaction, :random) }

  def create_cash_transaction_with_history(user:, user_bank_account:, installments_attributes:, **attrs)
    transaction = create(:cash_transaction, user:, context: user.main_context, user_bank_account:, **attrs)
    transaction.cash_installments.destroy_all

    installments_attributes.each do |installment_attrs|
      transaction.cash_installments.create!(installment_attrs)
    end

    transaction.update_column(:cash_installments_count, transaction.cash_installments.count)
    transaction.reload
  end

  describe "[ activerecord validations ]" do
    context "( presence, uniqueness, etc )" do
      it "is valid with valid attributes" do
        expect(subject).to be_valid
      end

      %i[description price cash_installments_count].each do |attribute|
        it { should validate_presence_of(attribute) }
      end
    end

    context "( associations )" do
      bt_models = %i[user]
      bto_models = %i[user_card user_bank_account investment_type reference_transactable subscription]
      hm_models = %i[card_installments investments exchanges cash_installments category_transactions categories entity_transactions entities]
      na_models = %i[category_transactions entity_transactions]

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
        user: subject.user,
        user_bank_account: subject.user_bank_account,
        description: "Context default",
        price: 100,
        date: Date.new(2026, 3, 23),
        month: 3,
        year: 2026,
        cash_installments_attributes: [
          { number: 1, price: 100, date: Date.new(2026, 3, 23), month: 3, year: 2026 }
        ]
      )

      transaction.valid?

      expect(transaction.context).to eq(subject.user.main_context)
    end

    it "recognises exchange return cash transactions by category" do
      exchange_return = subject.user.built_in_category("EXCHANGE RETURN")
      subject.categories << exchange_return
      subject.save

      expect(subject.exchange_return?).to be(true)
    end

    it "does not treat a local borrow return as a shared return flow without linkage or notification history" do
      borrow_return = subject.user.built_in_category("BORROW RETURN")
      counterpart_user = create(:user, :random)
      subject.entities << create(:entity, user: subject.user, entity_name: counterpart_user.first_name.upcase, entity_user: counterpart_user)
      subject.categories << borrow_return
      subject.save

      expect(subject.borrow_return?).to be(true)
      expect(subject.shared_return_flow?).to be(false)
    end

    it "does not treat a structurally similar shared return pair without a chain as a shared return flow" do
      transaction_user = create(:user, :random)
      transaction = create(
        :cash_transaction,
        user: transaction_user,
        context: transaction_user.main_context,
        user_bank_account: create(:user_bank_account, user: transaction_user, bank: create(:bank, :random)),
        description: "Shared return",
        price: -1000,
        date: Date.new(2026, 3, 10),
        month: 3,
        year: 2026,
        category_transactions_attributes: [],
        entity_transactions_attributes: [],
        cash_installments_attributes: []
      )
      transaction.category_transactions.destroy_all
      transaction.entity_transactions.destroy_all
      transaction.cash_installments.destroy_all
      transaction.cash_installments.create!(number: 1, date: Date.new(2026, 3, 10), month: 3, year: 2026, price: -1000, paid: false)
      transaction.update_column(:cash_installments_count, 1)

      counterpart_user = create(:user, :random)
      counterpart_entity = create(:entity, user: transaction_user, entity_name: counterpart_user.first_name.upcase, entity_user: counterpart_user)
      receiver_counterpart = create(:entity, user: counterpart_user, entity_name: transaction_user.first_name.upcase, entity_user: transaction_user)
      exchange_return = transaction_user.built_in_category("EXCHANGE RETURN")
      borrow_return = counterpart_user.built_in_category("BORROW RETURN")

      transaction.categories << exchange_return
      transaction.entity_transactions.create!(entity: counterpart_entity, is_payer: false, price: 0, price_to_be_returned: 0)

      candidate = create(
        :cash_transaction,
        user: counterpart_user,
        context: counterpart_user.main_context,
        user_bank_account: create(:user_bank_account, user: counterpart_user, bank: create(:bank, :random)),
        description: "Shared return",
        price: -1000,
        date: Date.new(2026, 3, 10),
        month: 3,
        year: 2026,
        category_transactions_attributes: [ { category_id: borrow_return.id } ],
        entity_transactions_attributes: [ { entity_id: receiver_counterpart.id, is_payer: false, price: 0, price_to_be_returned: 0 } ],
        cash_installments_attributes: [ { number: 1, date: Date.new(2026, 3, 10), month: 3, year: 2026, price: -1000, paid: false } ]
      )
      candidate.cash_installments.destroy_all
      candidate.cash_installments.create!(number: 1, date: Date.new(2026, 3, 10), month: 3, year: 2026, price: -1000, paid: false)
      candidate.update_column(:cash_installments_count, 1)

      expect(candidate).to be_present
      expect(transaction.shared_return_flow?).to be(false)
      expect(transaction.counterpart_shared_return_transaction).to be_nil
    end

    it "does not resolve a structurally matched counterpart without a canonical chain" do
      transaction_user = create(:user)
      transaction = create(
        :cash_transaction,
        user: transaction_user,
        context: transaction_user.main_context,
        user_bank_account: create(:user_bank_account, user: transaction_user, bank: create(:bank, :random)),
        description: "Shared return",
        price: -1000,
        date: Date.new(2026, 3, 10),
        month: 3,
        year: 2026,
        category_transactions_attributes: [],
        entity_transactions_attributes: [],
        cash_installments_attributes: []
      )
      transaction.category_transactions.destroy_all
      transaction.entity_transactions.destroy_all
      transaction.cash_installments.destroy_all
      transaction.cash_installments.create!(number: 1, date: Date.new(2026, 3, 10), month: 3, year: 2026, price: -1000, paid: false)
      transaction.update_columns(cash_installments_count: 1, created_at: Time.zone.local(2026, 3, 10, 12, 0, 0))

      counterpart_user = create(:user, :random)
      counterpart_entity = create(:entity, user: transaction_user, entity_name: counterpart_user.first_name.upcase, entity_user: counterpart_user)
      receiver_counterpart = create(:entity, user: counterpart_user, entity_name: transaction_user.first_name.upcase, entity_user: transaction_user)
      exchange_return = transaction_user.built_in_category("EXCHANGE RETURN")
      borrow_return = counterpart_user.built_in_category("BORROW RETURN")

      transaction.categories << exchange_return
      transaction.entity_transactions.create!(entity: counterpart_entity, is_payer: false, price: 0, price_to_be_returned: 0)

      stale_candidate = create(
        :cash_transaction,
        user: counterpart_user,
        context: counterpart_user.main_context,
        user_bank_account: create(:user_bank_account, user: counterpart_user, bank: create(:bank, :random)),
        description: "Shared return",
        price: -1000,
        date: Date.new(2025, 11, 10),
        month: 11,
        year: 2025,
        category_transactions_attributes: [ { category_id: borrow_return.id } ],
        entity_transactions_attributes: [ { entity_id: receiver_counterpart.id, is_payer: false, price: 0, price_to_be_returned: 0 } ],
        cash_installments_attributes: [ { number: 1, date: Date.new(2025, 11, 10), month: 11, year: 2025, price: -1000, paid: true } ]
      )
      stale_candidate.cash_installments.destroy_all
      stale_candidate.cash_installments.create!(number: 1, date: Date.new(2025, 11, 10), month: 11, year: 2025, price: -1000, paid: true)
      stale_candidate.update_columns(cash_installments_count: 1, created_at: Time.zone.local(2025, 11, 10, 12, 0, 0))

      expected_candidate = create(
        :cash_transaction,
        user: counterpart_user,
        context: counterpart_user.main_context,
        user_bank_account: create(:user_bank_account, user: counterpart_user, bank: create(:bank, :random)),
        description: "Shared return",
        price: -1000,
        date: Date.new(2026, 3, 10),
        month: 3,
        year: 2026,
        category_transactions_attributes: [ { category_id: borrow_return.id } ],
        entity_transactions_attributes: [ { entity_id: receiver_counterpart.id, is_payer: false, price: 0, price_to_be_returned: 0 } ],
        cash_installments_attributes: [ { number: 1, date: Date.new(2026, 3, 10), month: 3, year: 2026, price: -1000, paid: false } ]
      )
      expected_candidate.cash_installments.destroy_all
      expected_candidate.cash_installments.create!(number: 1, date: Date.new(2026, 3, 10), month: 3, year: 2026, price: -1000, paid: false)
      expected_candidate.update_columns(cash_installments_count: 1, created_at: Time.zone.local(2026, 3, 10, 12, 5, 0))

      expect(stale_candidate).to be_present
      expect(expected_candidate).to be_present
      expect(transaction.counterpart_shared_return_transaction).to be_nil
    end

    it "finds a receiver-side descendant through a canonical parent chain" do
      sender = create(:user, :random)
      receiver = create(:user, :random)
      sender_bank_account = create(:user_bank_account, user: sender, bank: create(:bank, :random))
      receiver_bank_account = create(:user_bank_account, user: receiver, bank: create(:bank, :random))
      sender_entity = create(:entity, user: sender, entity_name: receiver.first_name.upcase, entity_user: receiver)
      receiver_entity = create(:entity, user: receiver, entity_name: sender.first_name.upcase, entity_user: sender)

      source = create(
        :cash_transaction,
        user: sender,
        context: sender.main_context,
        user_bank_account: sender_bank_account,
        description: "Source exchange",
        price: -2_000,
        date: Date.new(2026, 3, 18),
        month: 3,
        year: 2026,
        category_transactions_attributes: [ { category_id: sender.built_in_category("EXCHANGE").id } ],
        entity_transactions_attributes: [ { entity_id: sender_entity.id, is_payer: true, price: -2_000, price_to_be_returned: -2_000 } ],
        cash_installments_attributes: [ { number: 1, date: Date.new(2026, 3, 18), month: 3, year: 2026, price: -2_000 } ]
      )
      sender_shared_return = create(
        :cash_transaction,
        user: sender,
        context: sender.main_context,
        user_bank_account: sender_bank_account,
        reference_transactable: source,
        description: "Sender exchange return",
        price: -2_000,
        date: Date.new(2026, 3, 20),
        month: 3,
        year: 2026,
        category_transactions_attributes: [ { category_id: sender.built_in_category("EXCHANGE RETURN").id } ],
        entity_transactions_attributes: [ { entity_id: sender_entity.id, is_payer: false, price: 0, price_to_be_returned: 0 } ],
        cash_installments_attributes: [ { number: 1, date: Date.new(2026, 3, 20), month: 3, year: 2026, price: -2_000 } ]
      )
      receiver_borrow_return = create(
        :cash_transaction,
        user: receiver,
        context: receiver.main_context,
        user_bank_account: receiver_bank_account,
        reference_transactable: sender_shared_return,
        description: "Receiver borrow return",
        price: -2_000,
        date: Date.new(2026, 3, 20),
        month: 3,
        year: 2026,
        category_transactions_attributes: [ { category_id: receiver.built_in_category("BORROW RETURN").id } ],
        entity_transactions_attributes: [ { entity_id: receiver_entity.id, is_payer: false, price: 0, price_to_be_returned: 0 } ],
        cash_installments_attributes: [ { number: 1, date: Date.new(2026, 3, 20), month: 3, year: 2026, price: -2_000 } ]
      )

      expect(source.first_reference_descendant(scope: receiver.main_context.cash_transactions)).to eq(receiver_borrow_return)
      expect(receiver_borrow_return.reference_root_transaction).to eq(source)
    end

    it "prefers the receiver exchange return as the shared-return counterpart in a canonical loan chain" do
      sender = create(:user, :random)
      receiver = create(:user, :random)
      sender_bank_account = create(:user_bank_account, user: sender, bank: create(:bank, :random))
      receiver_bank_account = create(:user_bank_account, user: receiver, bank: create(:bank, :random))
      sender_entity = create(:entity, user: sender, entity_name: receiver.first_name.upcase, entity_user: receiver)
      receiver_entity = create(:entity, user: receiver, entity_name: sender.first_name.upcase, entity_user: sender)

      sender_shared_return = create(
        :cash_transaction,
        user: sender,
        context: sender.main_context,
        user_bank_account: sender_bank_account,
        description: "Sender loan return",
        price: 5_000,
        date: Date.new(2026, 3, 20),
        month: 3,
        year: 2026,
        category_transactions_attributes: [ { category_id: sender.built_in_category("EXCHANGE RETURN").id } ],
        entity_transactions_attributes: [ { entity_id: sender_entity.id, is_payer: false, price: 0, price_to_be_returned: 0 } ],
        cash_installments_attributes: [ { number: 1, date: Date.new(2026, 3, 20), month: 3, year: 2026, price: 5_000, paid: false } ]
      )
      receiver_exchange = create(
        :cash_transaction,
        user: receiver,
        context: receiver.main_context,
        user_bank_account: receiver_bank_account,
        reference_transactable: sender_shared_return,
        description: "Receiver exchange",
        price: -5_000,
        date: Date.new(2026, 3, 17),
        month: 3,
        year: 2026,
        category_transactions_attributes: [ { category_id: receiver.built_in_category("EXCHANGE").id } ],
        entity_transactions_attributes: [ { entity_id: receiver_entity.id, is_payer: true, price: 5_000, price_to_be_returned: 5_000 } ],
        cash_installments_attributes: [ { number: 1, date: Date.new(2026, 3, 17), month: 3, year: 2026, price: -5_000, paid: false } ]
      )
      receiver_exchange_return = create(
        :cash_transaction,
        user: receiver,
        context: receiver.main_context,
        user_bank_account: receiver_bank_account,
        reference_transactable: receiver_exchange,
        description: "Receiver exchange return",
        price: 5_000,
        date: Date.new(2026, 3, 20),
        month: 3,
        year: 2026,
        category_transactions_attributes: [ { category_id: receiver.built_in_category("EXCHANGE RETURN").id } ],
        entity_transactions_attributes: [ { entity_id: receiver_entity.id, is_payer: false, price: 0, price_to_be_returned: 0 } ],
        cash_installments_attributes: [ { number: 1, date: Date.new(2026, 3, 20), month: 3, year: 2026, price: 5_000, paid: false } ]
      )

      expect(sender_shared_return.counterpart_shared_return_transaction).to eq(receiver_exchange_return)
    end

    it "finds the sender exchange return from a receiver exchange return through the canonical parent chain" do
      sender = create(:user, :random)
      receiver = create(:user, :random)
      sender_bank_account = create(:user_bank_account, user: sender, bank: create(:bank, :random))
      receiver_bank_account = create(:user_bank_account, user: receiver, bank: create(:bank, :random))
      sender_entity = create(:entity, user: sender, entity_name: receiver.first_name.upcase, entity_user: receiver)
      receiver_entity = create(:entity, user: receiver, entity_name: sender.first_name.upcase, entity_user: sender)

      sender_shared_return = create(
        :cash_transaction,
        user: sender,
        context: sender.main_context,
        user_bank_account: sender_bank_account,
        reference_transactable: create(
          :cash_transaction,
          user: sender,
          context: sender.main_context,
          user_bank_account: sender_bank_account,
          cash_transaction_type: "Exchange",
          description: "Sender source exchange",
          price: -5_000,
          date: Date.new(2026, 3, 17),
          month: 3,
          year: 2026,
          category_transactions_attributes: [ { category_id: sender.built_in_category("EXCHANGE").id } ],
          entity_transactions_attributes: [ { entity_id: sender_entity.id, is_payer: true, price: -5_000, price_to_be_returned: -5_000 } ],
          cash_installments_attributes: [ { number: 1, date: Date.new(2026, 3, 17), month: 3, year: 2026, price: -5_000, paid: false } ]
        ),
        description: "Sender loan return",
        price: 5_000,
        date: Date.new(2026, 3, 20),
        month: 3,
        year: 2026,
        category_transactions_attributes: [ { category_id: sender.built_in_category("EXCHANGE RETURN").id } ],
        entity_transactions_attributes: [ { entity_id: sender_entity.id, is_payer: false, price: 0, price_to_be_returned: 0 } ],
        cash_installments_attributes: [ { number: 1, date: Date.new(2026, 3, 20), month: 3, year: 2026, price: 5_000, paid: false } ]
      )
      receiver_exchange = create(
        :cash_transaction,
        user: receiver,
        context: receiver.main_context,
        user_bank_account: receiver_bank_account,
        reference_transactable: sender_shared_return,
        description: "Receiver exchange",
        price: -5_000,
        date: Date.new(2026, 3, 17),
        month: 3,
        year: 2026,
        category_transactions_attributes: [ { category_id: receiver.built_in_category("EXCHANGE").id } ],
        entity_transactions_attributes: [ { entity_id: receiver_entity.id, is_payer: true, price: 5_000, price_to_be_returned: 5_000 } ],
        cash_installments_attributes: [ { number: 1, date: Date.new(2026, 3, 17), month: 3, year: 2026, price: -5_000, paid: false } ]
      )
      receiver_exchange_return = create(
        :cash_transaction,
        user: receiver,
        context: receiver.main_context,
        user_bank_account: receiver_bank_account,
        reference_transactable: receiver_exchange,
        description: "Receiver exchange return",
        price: 5_000,
        date: Date.new(2026, 3, 20),
        month: 3,
        year: 2026,
        category_transactions_attributes: [ { category_id: receiver.built_in_category("EXCHANGE RETURN").id } ],
        entity_transactions_attributes: [ { entity_id: receiver_entity.id, is_payer: false, price: 0, price_to_be_returned: 0 } ],
        cash_installments_attributes: [ { number: 1, date: Date.new(2026, 3, 20), month: 3, year: 2026, price: 5_000, paid: false } ]
      )

      expect(receiver_exchange_return.counterpart_shared_return_transaction).to eq(sender_shared_return)
    end

    it "blocks unpaying a local borrow return installment with paid history" do
      user = create(:user)
      bank_account = create(:user_bank_account, user:, bank: create(:bank, :random))
      counterpart_user = create(:user, :random)
      counterpart_entity = create(:entity, user:, entity_name: counterpart_user.first_name.upcase, entity_user: counterpart_user)
      borrow_return = user.built_in_category("BORROW RETURN")

      transaction = create(
        :cash_transaction,
        user:,
        context: user.main_context,
        user_bank_account: bank_account,
        description: "Local borrow return",
        price: -1000,
        date: Date.new(2025, 2, 10),
        month: 2,
        year: 2025,
        category_transactions_attributes: [
          { category_id: borrow_return.id }
        ],
        entity_transactions_attributes: [
          { entity_id: counterpart_entity.id, is_payer: false, price: 0, price_to_be_returned: 0 }
        ],
        cash_installments_attributes: [
          { number: 1, price: -500, date: Date.new(2025, 1, 10), month: 1, year: 2025, paid: true },
          { number: 2, price: -500, date: Date.new(2025, 2, 10), month: 2, year: 2025, paid: true }
        ]
      )

      transaction.cash_installments.last.paid = false

      expect(transaction).not_to be_valid
      expect(transaction.errors.details[:base]).to include(error: :paid_history_locked)
    end

    it "detects the latest paid installment boundary and future-only edit allowance" do
      user = create(:user)
      bank_account = create(:user_bank_account, user:, bank: create(:bank, :random))
      transaction = create(
        :cash_transaction,
        user:,
        context: user.main_context,
        user_bank_account: bank_account,
        description: "Safety boundary",
        price: 3000,
        date: Date.new(2026, 3, 10),
        month: 3,
        year: 2026,
        cash_installments_attributes: [
          { number: 1, price: 1000, date: Date.new(2026, 3, 10), month: 3, year: 2026, paid: true },
          { number: 2, price: 1000, date: Date.new(2026, 4, 10), month: 4, year: 2026, paid: false },
          { number: 3, price: 1000, date: Date.new(2026, 5, 10), month: 5, year: 2026, paid: false }
        ]
      )

      expect(transaction).to be_paid_history
      expect(transaction).to be_partially_paid
      expect(transaction.latest_paid_installment_date).to eq(Date.new(2026, 3, 10))
      expect(transaction.can_edit_unpaid_future_installments?([ Date.new(2026, 4, 20), Date.new(2026, 5, 20) ])).to be(true)
      expect(transaction.can_change_installment_structure?(proposed_dates: [ Date.new(2026, 4, 20) ])).to be(true)
      expect(transaction.can_edit_unpaid_future_installments?([ Date.new(2026, 3, 10) ])).to be(false)
      expect(transaction.can_change_allocation?).to be(false)
      expect(transaction.can_destroy_with_history?).to be(false)
    end

    it "allows installment-structure and allocation predicates while no paid history exists" do
      user = create(:user)
      bank_account = create(:user_bank_account, user:, bank: create(:bank, :random))
      transaction = create(
        :cash_transaction,
        user:,
        context: user.main_context,
        user_bank_account: bank_account,
        description: "Future only",
        price: 2000,
        date: Date.new(2026, 4, 10),
        month: 4,
        year: 2026,
        cash_installments_attributes: [
          { number: 1, price: 1000, date: Date.new(2026, 4, 10), month: 4, year: 2026, paid: false },
          { number: 2, price: 1000, date: Date.new(2026, 5, 10), month: 5, year: 2026, paid: false }
        ]
      )

      expect(transaction.paid_history?).to be(false)
      expect(transaction.partially_paid?).to be(false)
      expect(transaction.latest_paid_installment_date).to be_nil
      expect(transaction.can_edit_unpaid_future_installments?([ Date.new(2026, 4, 10) ])).to be(true)
      expect(transaction.can_change_allocation?).to be(true)
      expect(transaction.can_destroy_with_history?).to be(true)
    end

    it "blocks category allocation changes once paid history exists" do
      user = create(:user)
      bank_account = create(:user_bank_account, user:, bank: create(:bank, :random))
      category = create(:category, user:, category_name: "FOOD")
      replacement_category = create(:category, user:, category_name: "TRANSPORT")
      transaction = create_cash_transaction_with_history(
        user:,
        user_bank_account: bank_account,
        description: "Locked allocation",
        price: 3000,
        date: Date.new(2026, 3, 10),
        month: 3,
        year: 2026,
        category_transactions_attributes: [
          { category_id: category.id }
        ],
        installments_attributes: [
          { number: 1, price: 1000, date: Date.new(2026, 3, 10), month: 3, year: 2026, paid: true },
          { number: 2, price: 1000, date: Date.new(2026, 4, 10), month: 4, year: 2026, paid: false },
          { number: 3, price: 1000, date: Date.new(2026, 5, 10), month: 5, year: 2026, paid: false }
        ]
      )

      transaction.categories = [ replacement_category ]

      expect(transaction).to be_invalid
      expect(transaction.errors[:base]).to include(I18n.t("activerecord.errors.models.cash_transaction.attributes.base.allocation_locked_after_payment"))
    end

    it "allows unpaid future installment edits after the latest paid boundary" do
      user = create(:user)
      bank_account = create(:user_bank_account, user:, bank: create(:bank, :random))
      transaction = create_cash_transaction_with_history(
        user:,
        user_bank_account: bank_account,
        description: "Future edits",
        price: 3000,
        date: Date.new(2026, 3, 10),
        month: 3,
        year: 2026,
        installments_attributes: [
          { number: 1, price: 1000, date: Date.new(2026, 3, 10), month: 3, year: 2026, paid: true },
          { number: 2, price: 1000, date: Date.new(2026, 4, 10), month: 4, year: 2026, paid: false },
          { number: 3, price: 1000, date: Date.new(2026, 5, 10), month: 5, year: 2026, paid: false }
        ]
      )

      second_installment = transaction.cash_installments.find_by!(number: 2)
      third_installment = transaction.cash_installments.find_by!(number: 3)

      transaction.cash_installments_attributes = [
        { id: second_installment.id, number: 2, price: second_installment.price, date: Date.new(2026, 4, 15), month: 4, year: 2026, paid: false },
        { id: third_installment.id, number: 3, price: third_installment.price, date: Date.new(2026, 5, 15), month: 5, year: 2026, paid: false }
      ]

      expect(transaction).to be_valid
    end

    it "blocks unpaid installment edits that cross the paid boundary" do
      user = create(:user)
      bank_account = create(:user_bank_account, user:, bank: create(:bank, :random))
      transaction = create_cash_transaction_with_history(
        user:,
        user_bank_account: bank_account,
        description: "Unsafe future edit",
        price: 3000,
        date: Date.new(2026, 3, 10),
        month: 3,
        year: 2026,
        installments_attributes: [
          { number: 1, price: 1000, date: Date.new(2026, 3, 10), month: 3, year: 2026, paid: true },
          { number: 2, price: 1000, date: Date.new(2026, 4, 10), month: 4, year: 2026, paid: false },
          { number: 3, price: 1000, date: Date.new(2026, 5, 10), month: 5, year: 2026, paid: false }
        ]
      )

      second_installment = transaction.cash_installments.find_by!(number: 2)

      transaction.cash_installments_attributes = [
        { id: second_installment.id, number: 2, price: second_installment.price, date: Date.new(2026, 3, 10), month: 3, year: 2026, paid: false }
      ]

      expect(transaction).to be_invalid
      expect(transaction.errors[:base]).to include(I18n.t("activerecord.errors.models.cash_transaction.attributes.base.paid_history_locked"))
    end

    it "blocks parent price changes once paid history exists" do
      user = create(:user)
      bank_account = create(:user_bank_account, user:, bank: create(:bank, :random))
      transaction = create_cash_transaction_with_history(
        user:,
        user_bank_account: bank_account,
        description: "Locked parent fields",
        price: 3000,
        date: Date.new(2026, 3, 10),
        month: 3,
        year: 2026,
        installments_attributes: [
          { number: 1, price: 1000, date: Date.new(2026, 3, 10), month: 3, year: 2026, paid: true },
          { number: 2, price: 1000, date: Date.new(2026, 4, 10), month: 4, year: 2026, paid: false },
          { number: 3, price: 1000, date: Date.new(2026, 5, 10), month: 5, year: 2026, paid: false }
        ]
      )

      transaction.price = 3500

      expect(transaction).to be_invalid
      expect(transaction.errors[:base]).to include(I18n.t("activerecord.errors.models.cash_transaction.attributes.base.paid_history_locked"))
    end

    it "allows a confirmed month-boundary correction for a paid installment" do
      user = create(:user)
      bank_account = create(:user_bank_account, user:, bank: create(:bank, :random))
      transaction = create_cash_transaction_with_history(
        user:,
        user_bank_account: bank_account,
        description: "Month boundary correction",
        price: 3000,
        date: Date.new(2026, 3, 31),
        month: 3,
        year: 2026,
        installments_attributes: [
          { number: 1, price: 1000, date: Date.new(2026, 3, 31), month: 3, year: 2026, paid: true },
          { number: 2, price: 1000, date: Date.new(2026, 4, 10), month: 4, year: 2026, paid: false },
          { number: 3, price: 1000, date: Date.new(2026, 5, 10), month: 5, year: 2026, paid: false }
        ]
      )

      first_installment = transaction.cash_installments.find_by!(number: 1)
      transaction.historical_correction_confirmation = true
      transaction.cash_installments_attributes = [
        { id: first_installment.id, number: 1, price: first_installment.price, date: Date.new(2026, 4, 1), month: 4, year: 2026, paid: true }
      ]

      expect(transaction).to be_valid
    end

    it "allows a confirmed current-month unpay for a paid installment" do
      user = create(:user)
      bank_account = create(:user_bank_account, user:, bank: create(:bank, :random))
      today = Time.zone.today
      transaction = create_cash_transaction_with_history(
        user:,
        user_bank_account: bank_account,
        description: "Current month unpay",
        price: 2000,
        date: today,
        month: today.month,
        year: today.year,
        installments_attributes: [
          { number: 1, price: 2000, date: today, month: today.month, year: today.year, paid: true }
        ]
      )

      first_installment = transaction.cash_installments.find_by!(number: 1)
      transaction.historical_correction_confirmation = true
      transaction.cash_installments_attributes = [
        { id: first_installment.id, number: 1, price: first_installment.price, date: first_installment.date, month: first_installment.month,
          year: first_installment.year, paid: false }
      ]

      expect(transaction).to be_valid
    end

    it "allows a confirmed paid exchange return installment price correction" do
      user = create(:user)
      bank_account = create(:user_bank_account, user:, bank: create(:bank, :random))
      exchange_return = create_cash_transaction_with_history(
        user:,
        user_bank_account: bank_account,
        description: "Paid exchange return correction",
        price: -2000,
        date: Date.new(2026, 3, 10),
        month: 3,
        year: 2026,
        cash_transaction_type: "Exchange",
        installments_attributes: [
          { number: 1, price: -1000, date: Date.new(2026, 3, 10), month: 3, year: 2026, paid: true },
          { number: 2, price: -1000, date: Date.new(2026, 4, 10), month: 4, year: 2026, paid: false }
        ]
      )
      exchange_return.categories = [ user.built_in_category("EXCHANGE RETURN") ]
      exchange_return.save!

      first_installment = exchange_return.cash_installments.find_by!(number: 1)
      exchange_return.historical_correction_confirmation = true
      exchange_return.price = -2500
      exchange_return.cash_installments_attributes = [
        { id: first_installment.id, number: 1, price: -1500, date: first_installment.date, month: first_installment.month, year: first_installment.year, paid: true }
      ]

      expect(exchange_return).to be_valid
    end

    it "allows a confirmed paid amount correction on a normal cash transaction" do
      user = create(:user)
      bank_account = create(:user_bank_account, user:, bank: create(:bank, :random))
      transaction = create_cash_transaction_with_history(
        user:,
        user_bank_account: bank_account,
        description: "Paid amount correction",
        price: 3000,
        date: Date.new(2026, 3, 10),
        month: 3,
        year: 2026,
        installments_attributes: [
          { number: 1, price: 1000, date: Date.new(2026, 3, 10), month: 3, year: 2026, paid: true },
          { number: 2, price: 1000, date: Date.new(2026, 4, 10), month: 4, year: 2026, paid: false },
          { number: 3, price: 1000, date: Date.new(2026, 5, 10), month: 5, year: 2026, paid: false }
        ]
      )

      first_installment = transaction.cash_installments.find_by!(number: 1)
      second_installment = transaction.cash_installments.find_by!(number: 2)
      third_installment = transaction.cash_installments.find_by!(number: 3)

      transaction.historical_correction_confirmation = true
      transaction.price = 3500
      transaction.cash_installments_attributes = [
        { id: first_installment.id, number: 1, price: 1500, date: first_installment.date, month: first_installment.month, year: first_installment.year, paid: true },
        { id: second_installment.id, number: 2, price: 1000, date: second_installment.date, month: second_installment.month, year: second_installment.year,
          paid: false },
        { id: third_installment.id, number: 3, price: 1000, date: third_installment.date, month: third_installment.month, year: third_installment.year, paid: false }
      ]

      expect(transaction).to be_valid
    end

    it "blocks destruction when paid history exists" do
      user = create(:user)
      bank_account = create(:user_bank_account, user:, bank: create(:bank, :random))
      transaction = create_cash_transaction_with_history(
        user:,
        user_bank_account: bank_account,
        description: "Locked destroy",
        price: 2000,
        date: Date.new(2026, 3, 10),
        month: 3,
        year: 2026,
        installments_attributes: [
          { number: 1, price: 1000, date: Date.new(2026, 3, 10), month: 3, year: 2026, paid: true },
          { number: 2, price: 1000, date: Date.new(2026, 4, 10), month: 4, year: 2026, paid: false }
        ]
      )

      expect(transaction.destroy).to be(false)
      expect(transaction.errors[:base]).to include(I18n.t("activerecord.errors.models.cash_transaction.attributes.base.destroy_locked_after_payment"))
    end

    it "blocks destruction for a borrow return that is linked to a shared-return parent" do
      sender = create(:user, :random)
      receiver = create(:user, :random)
      sender_bank_account = create(:user_bank_account, user: sender, bank: create(:bank, :random))
      receiver_bank_account = create(:user_bank_account, user: receiver, bank: create(:bank, :random))
      create(:entity, user: sender, entity_name: receiver.first_name.upcase, entity_user: receiver)
      receiver_counterpart = create(:entity, user: receiver, entity_name: sender.first_name.upcase, entity_user: sender)

      sender_return = create(
        :cash_transaction,
        user: sender,
        context: sender.main_context,
        user_bank_account: sender_bank_account,
        description: "Linked sender return",
        price: -1000,
        date: Date.new(2026, 3, 10),
        month: 3,
        year: 2026,
        category_transactions_attributes: [ { category_id: sender.built_in_category("EXCHANGE RETURN").id } ],
        entity_transactions_attributes: [ { entity_id: sender.entities.that_are_users.find_by!(entity_user: receiver).id, is_payer: false, price: 0,
                                            price_to_be_returned: 0 } ],
        cash_installments_attributes: [ { number: 1, date: Date.new(2026, 3, 10), month: 3, year: 2026, price: -1000, paid: false } ]
      )

      receiver_return = create(
        :cash_transaction,
        user: receiver,
        context: receiver.main_context,
        user_bank_account: receiver_bank_account,
        reference_transactable: sender_return,
        description: "Linked receiver borrow return",
        price: -1000,
        date: Date.new(2026, 3, 10),
        month: 3,
        year: 2026,
        category_transactions_attributes: [ { category_id: receiver.built_in_category("BORROW RETURN").id } ],
        entity_transactions_attributes: [ { entity_id: receiver_counterpart.id, is_payer: false, price: 0, price_to_be_returned: 0 } ],
        cash_installments_attributes: [ { number: 1, date: Date.new(2026, 3, 10), month: 3, year: 2026, price: -1000, paid: false } ]
      )

      expect(receiver_return.destroy).to be(false)
      expect(receiver_return.errors[:base]).to include(I18n.t("activerecord.errors.models.cash_transaction.attributes.base.destroy_linked_shared_return"))
    end

    it "allows destroying a local borrow return without a reference transactable" do
      sender = create(:user, :random)
      receiver = create(:user, :random)
      receiver_bank_account = create(:user_bank_account, user: receiver, bank: create(:bank, :random))
      receiver_counterpart = create(:entity, user: receiver, entity_name: sender.first_name.upcase, entity_user: sender)

      local_borrow_return = create(
        :cash_transaction,
        user: receiver,
        context: receiver.main_context,
        user_bank_account: receiver_bank_account,
        description: "Local borrow return",
        price: -1000,
        date: Date.new(2026, 3, 10),
        month: 3,
        year: 2026,
        category_transactions_attributes: [ { category_id: receiver.built_in_category("BORROW RETURN").id } ],
        entity_transactions_attributes: [ { entity_id: receiver_counterpart.id, is_payer: false, price: 0, price_to_be_returned: 0 } ],
        cash_installments_attributes: [ { number: 1, date: Date.new(2026, 3, 10), month: 3, year: 2026, price: -1000, paid: false } ]
      )

      local_borrow_return.destroy

      expect(local_borrow_return).to be_destroyed
    end

    it "allows confirmed destruction when paid history exists" do
      user = create(:user)
      bank_account = create(:user_bank_account, user:, bank: create(:bank, :random))
      transaction = create_cash_transaction_with_history(
        user:,
        user_bank_account: bank_account,
        description: "Confirmed destroy",
        price: 2000,
        date: Date.new(2026, 3, 10),
        month: 3,
        year: 2026,
        installments_attributes: [
          { number: 1, price: 1000, date: Date.new(2026, 3, 10), month: 3, year: 2026, paid: true },
          { number: 2, price: 1000, date: Date.new(2026, 4, 10), month: 4, year: 2026, paid: false }
        ]
      )

      transaction.historical_correction_confirmation = true

      transaction.destroy

      expect(transaction).to be_destroyed
    end

    it "builds reimbursement notification headers for cash exchanges when the intent is reimbursement" do
      rikki = create(:user, first_name: "Rikki", email: "rikki@example.com")
      gigi = create(:user, first_name: "Gigi", email: "gigi@example.com")
      rikki_bank_account = create(:user_bank_account, user: rikki, bank: create(:bank, :random))
      create(:entity, user: rikki, entity_name: "GIGI", entity_user: gigi)
      gigi_entity_for_rikki = create(:entity, user: gigi, entity_name: "RIKKI", entity_user: rikki)
      conversation = Conversation.create!.tap do |record| # rubocop:disable Lint/UselessAssignment
        record.conversation_participants.create!(user: rikki)
        record.conversation_participants.create!(user: gigi)
      end

      described_class.create!(
        user: rikki,
        user_bank_account: rikki_bank_account,
        description: "WATER BILL",
        price: 5_000,
        date: Date.new(2026, 3, 17),
        month: 3,
        year: 2026,
        friend_notification_intent: "reimbursement",
        category_transactions_attributes: [
          { category_id: rikki.built_in_category("EXCHANGE").id }
        ],
        cash_installments_attributes: [
          { number: 1, price: 5_000, date: Date.new(2026, 3, 17), month: 3, year: 2026 }
        ],
        entity_transactions_attributes: [
          {
            entity_id: rikki.entities.that_are_users.find_by(entity_user: gigi).id,
            is_payer: true,
            price: -5_000,
            price_to_be_returned: -5_000,
            exchanges_count: 1,
            exchanges_attributes: [
              { number: 1, price: -5_000, date: Date.new(2026, 3, 20), month: 3, year: 2026 }
            ]
          }
        ]
      )

      headers = JSON.parse(Message.last.headers)

      expect(headers).to include("version" => "message_notification_v2")
      expect(headers.fetch("event")).to include(
        "action" => "create",
        "receiver_first_name" => "Gigi",
        "transaction_type" => "CashTransaction"
      )
      expect(headers.fetch("replay")).to include(
        "version" => "cash_exchange_v2",
        "intent" => "reimbursement",
        "category_ids" => gigi.built_in_category("BORROW RETURN").id,
        "entity_ids" => gigi_entity_for_rikki.id
      )
      expect(headers.fetch("replay").fetch("cash_installments_attributes")).to contain_exactly(
        a_hash_including("price" => 5000, "date" => "2026-03-20T00:00:00.000-03:00")
      )
      expect(headers.fetch("replay").fetch("entity_transactions_attributes")).to contain_exactly(
        a_hash_including(
          "is_payer" => false,
          "price" => 0,
          "price_to_be_returned" => 0,
          "entity_id" => gigi_entity_for_rikki.id,
          "exchanges_count" => 0
        )
      )
    end

    it "defaults to loan notification headers for pure exchange cash transactions" do
      rikki = create(:user, first_name: "Rikki", email: "rikki@example.com")
      gigi = create(:user, first_name: "Gigi", email: "gigi@example.com")
      rikki_bank_account = create(:user_bank_account, user: rikki, bank: create(:bank, :random))
      create(:entity, user: rikki, entity_name: "GIGI", entity_user: gigi)
      gigi_entity_for_rikki = create(:entity, user: gigi, entity_name: "RIKKI", entity_user: rikki)
      conversation = Conversation.create!.tap do |record| # rubocop:disable Lint/UselessAssignment
        record.conversation_participants.create!(user: rikki)
        record.conversation_participants.create!(user: gigi)
      end

      described_class.create!(
        user: rikki,
        user_bank_account: rikki_bank_account,
        description: "LOAN",
        price: 5_000,
        date: Date.new(2026, 3, 17),
        month: 3,
        year: 2026,
        category_transactions_attributes: [
          { category_id: rikki.built_in_category("EXCHANGE").id }
        ],
        cash_installments_attributes: [
          { number: 1, price: 5_000, date: Date.new(2026, 3, 17), month: 3, year: 2026 }
        ],
        entity_transactions_attributes: [
          {
            entity_id: rikki.entities.that_are_users.find_by(entity_user: gigi).id,
            is_payer: true,
            price: -5_000,
            price_to_be_returned: -5_000,
            exchanges_count: 1,
            exchanges_attributes: [
              { number: 1, price: -5_000, date: Date.new(2026, 3, 20), month: 3, year: 2026 }
            ]
          }
        ]
      )

      headers = JSON.parse(Message.last.headers)

      expect(headers).to include("version" => "message_notification_v2")
      expect(headers.fetch("replay")).to include(
        "version" => "cash_exchange_v2",
        "intent" => "loan",
        "category_ids" => gigi.built_in_category("EXCHANGE").id
      )
      expect(headers.fetch("replay").fetch("entity_transactions_attributes")).to contain_exactly(
        a_hash_including(
          "is_payer" => true,
          "price" => 5000,
          "price_to_be_returned" => 5000,
          "entity_id" => gigi_entity_for_rikki.id,
          "exchanges_count" => 1
        )
      )
    end

    it "hydrates the effective friend notification intent from the latest active message headers" do
      rikki = create(:user, first_name: "Rikki", email: "rikki@example.com")
      gigi = create(:user, first_name: "Gigi", email: "gigi@example.com")
      rikki_bank_account = create(:user_bank_account, user: rikki, bank: create(:bank, :random))
      create(:entity, user: rikki, entity_name: "GIGI", entity_user: gigi)
      create(:entity, user: gigi, entity_name: "RIKKI", entity_user: rikki)
      conversation = Conversation.create!.tap do |record|
        record.conversation_participants.create!(user: rikki)
        record.conversation_participants.create!(user: gigi)
      end

      transaction = described_class.create!(
        user: rikki,
        user_bank_account: rikki_bank_account,
        description: "WATER BILL",
        price: 5_000,
        date: Date.new(2026, 3, 17),
        month: 3,
        year: 2026,
        category_transactions_attributes: [
          { category_id: rikki.built_in_category("EXCHANGE").id }
        ],
        cash_installments_attributes: [
          { number: 1, price: 5_000, date: Date.new(2026, 3, 17), month: 3, year: 2026 }
        ],
        entity_transactions_attributes: [
          {
            entity_id: rikki.entities.that_are_users.find_by(entity_user: gigi).id,
            is_payer: true,
            price: -5_000,
            price_to_be_returned: -5_000,
            exchanges_count: 1,
            exchanges_attributes: [
              { number: 1, price: -5_000, date: Date.new(2026, 3, 20), month: 3, year: 2026 }
            ]
          }
        ]
      )

      conversation.messages.create!(
        user: rikki,
        reference_transactable: transaction,
        body: "Old",
        headers: { id: transaction.id, type: "CashTransaction", intent: "loan" }.to_json
      )
      conversation.messages.create!(
        user: rikki,
        reference_transactable: transaction,
        body: "New",
        headers: { id: transaction.id, type: "CashTransaction", intent: "reimbursement" }.to_json
      )

      expect(transaction.effective_friend_notification_intent).to eq("reimbursement")
    end

    it "hydrates the effective friend notification intent from the canonical reference family" do
      rikki = create(:user, first_name: "Rikki", email: "rikki@example.com")
      gigi = create(:user, first_name: "Gigi", email: "gigi@example.com")
      rikki_bank_account = create(:user_bank_account, user: rikki, bank: create(:bank, :random))
      create(:entity, user: rikki, entity_name: "GIGI", entity_user: gigi)
      create(:entity, user: gigi, entity_name: "RIKKI", entity_user: rikki)
      conversation = Conversation.create!.tap do |record|
        record.conversation_participants.create!(user: rikki)
        record.conversation_participants.create!(user: gigi)
      end

      source_transaction = described_class.create!(
        user: rikki,
        user_bank_account: rikki_bank_account,
        description: "WATER BILL",
        price: 5_000,
        date: Date.new(2026, 3, 17),
        month: 3,
        year: 2026,
        category_transactions_attributes: [
          { category_id: rikki.built_in_category("EXCHANGE").id }
        ],
        cash_installments_attributes: [
          { number: 1, price: 5_000, date: Date.new(2026, 3, 17), month: 3, year: 2026 }
        ],
        entity_transactions_attributes: [
          {
            entity_id: rikki.entities.that_are_users.find_by(entity_user: gigi).id,
            is_payer: true,
            price: -5_000,
            price_to_be_returned: -5_000,
            exchanges_count: 1,
            exchanges_attributes: [
              { number: 1, price: -5_000, date: Date.new(2026, 3, 20), month: 3, year: 2026 }
            ]
          }
        ]
      )
      sender_exchange_return = described_class.create!(
        user: rikki,
        context: rikki.main_context,
        user_bank_account: rikki_bank_account,
        reference_transactable: source_transaction,
        description: "WATER BILL RETURN",
        price: 5_000,
        date: Date.new(2026, 3, 20),
        month: 3,
        year: 2026,
        category_transactions_attributes: [
          { category_id: rikki.built_in_category("EXCHANGE RETURN").id }
        ],
        cash_installments_attributes: [
          { number: 1, price: 5_000, date: Date.new(2026, 3, 20), month: 3, year: 2026 }
        ],
        entity_transactions_attributes: [
          {
            entity_id: rikki.entities.that_are_users.find_by(entity_user: gigi).id,
            is_payer: false,
            price: 0,
            price_to_be_returned: 0
          }
        ]
      )

      conversation.messages.create!(
        user: rikki,
        reference_transactable: source_transaction,
        body: "Old",
        headers: { id: source_transaction.id, type: "CashTransaction", intent: "loan" }.to_json
      )
      conversation.messages.create!(
        user: rikki,
        reference_transactable: source_transaction,
        body: "New",
        headers: { id: source_transaction.id, type: "CashTransaction", intent: "reimbursement" }.to_json
      )

      expect(sender_exchange_return.effective_friend_notification_intent).to eq("reimbursement")
    end

    it "supersedes previous assistant messages across the canonical reference family" do
      rikki = create(:user, first_name: "Rikki", email: "rikki@example.com")
      gigi = create(:user, first_name: "Gigi", email: "gigi@example.com")
      rikki_bank_account = create(:user_bank_account, user: rikki, bank: create(:bank, :random))
      create(:entity, user: rikki, entity_name: "GIGI", entity_user: gigi)
      create(:entity, user: gigi, entity_name: "RIKKI", entity_user: rikki)
      conversation = Conversation.create!.tap do |record|
        record.conversation_participants.create!(user: rikki)
        record.conversation_participants.create!(user: gigi)
      end

      source_transaction = described_class.create!(
        user: rikki,
        user_bank_account: rikki_bank_account,
        description: "WATER BILL",
        price: 5_000,
        date: Date.new(2026, 3, 17),
        month: 3,
        year: 2026,
        category_transactions_attributes: [
          { category_id: rikki.built_in_category("EXCHANGE").id }
        ],
        cash_installments_attributes: [
          { number: 1, price: 5_000, date: Date.new(2026, 3, 17), month: 3, year: 2026 }
        ],
        entity_transactions_attributes: [
          {
            entity_id: rikki.entities.that_are_users.find_by(entity_user: gigi).id,
            is_payer: true,
            price: -5_000,
            price_to_be_returned: -5_000,
            exchanges_count: 1,
            exchanges_attributes: [
              { number: 1, price: -5_000, date: Date.new(2026, 3, 20), month: 3, year: 2026 }
            ]
          }
        ]
      )
      sender_exchange_return = described_class.create!(
        user: rikki,
        context: rikki.main_context,
        user_bank_account: rikki_bank_account,
        reference_transactable: source_transaction,
        description: "WATER BILL RETURN",
        price: 5_000,
        date: Date.new(2026, 3, 20),
        month: 3,
        year: 2026,
        category_transactions_attributes: [
          { category_id: rikki.built_in_category("EXCHANGE RETURN").id }
        ],
        cash_installments_attributes: [
          { number: 1, price: 5_000, date: Date.new(2026, 3, 20), month: 3, year: 2026 }
        ],
        entity_transactions_attributes: [
          {
            entity_id: rikki.entities.that_are_users.find_by(entity_user: gigi).id,
            is_payer: false,
            price: 0,
            price_to_be_returned: 0
          }
        ]
      )

      outdated_source_message = conversation.messages.create!(
        user: rikki,
        reference_transactable: source_transaction,
        body: "notification:update"
      )
      outdated_descendant_message = conversation.messages.create!(
        user: rikki,
        reference_transactable: sender_exchange_return,
        body: "notification:update"
      )
      latest_message = conversation.messages.create!(
        user: rikki,
        reference_transactable: source_transaction,
        body: "notification:update"
      )

      source_transaction.send(:supersede_previous_messages, conversation, latest_message)

      expect(outdated_source_message.reload.superseded_by).to eq(latest_message)
      expect(outdated_descendant_message.reload.superseded_by).to eq(latest_message)
    end

    it "builds v2 destroy notification headers for exchange cash transactions" do
      rikki = create(:user, first_name: "Rikki", email: "rikki@example.com")
      gigi = create(:user, first_name: "Gigi", email: "gigi@example.com")
      rikki_bank_account = create(:user_bank_account, user: rikki, bank: create(:bank, :random))
      gigi_bank_account = create(:user_bank_account, user: gigi, bank: create(:bank, :random))
      create(:entity, user: rikki, entity_name: "GIGI", entity_user: gigi)
      create(:entity, user: gigi, entity_name: "RIKKI", entity_user: rikki)
      Conversation.create!.tap do |record|
        record.conversation_participants.create!(user: rikki)
        record.conversation_participants.create!(user: gigi)
      end

      transaction = described_class.create!(
        user: rikki,
        user_bank_account: rikki_bank_account,
        description: "LOAN",
        price: 5_000,
        date: Date.new(2026, 3, 17),
        month: 3,
        year: 2026,
        category_transactions_attributes: [
          { category_id: rikki.built_in_category("EXCHANGE").id }
        ],
        cash_installments_attributes: [
          { number: 1, price: 5_000, date: Date.new(2026, 3, 17), month: 3, year: 2026 }
        ],
        entity_transactions_attributes: [
          {
            entity_id: rikki.entities.that_are_users.find_by(entity_user: gigi).id,
            is_payer: true,
            price: -5_000,
            price_to_be_returned: -5_000,
            exchanges_count: 1,
            exchanges_attributes: [
              { number: 1, price: -5_000, date: Date.new(2026, 3, 20), month: 3, year: 2026 }
            ]
          }
        ]
      )

      receiver_transaction = create(
        :cash_transaction,
        user: gigi,
        user_bank_account: gigi_bank_account,
        reference_transactable: transaction,
        description: "LOAN",
        price: -5_000,
        date: Date.new(2026, 3, 17),
        month: 3,
        year: 2026,
        category_transactions: [ build(:category_transaction, category: gigi.built_in_category("EXCHANGE")) ],
        cash_installments: [ build(:cash_installment, number: 1, price: -5_000, date: Date.new(2026, 3, 17), month: 3, year: 2026) ]
      )

      transaction.destroy

      message = Message.order(:id).last
      headers = JSON.parse(message.headers)

      expect(headers).to include("version" => "message_notification_v2")
      expect(message.reference_transactable).to eq(receiver_transaction)
      expect(headers.fetch("event")).to include(
        "action" => "destroy",
        "receiver_first_name" => "Gigi",
        "transaction_type" => "CashTransaction"
      )
      expect(headers.dig("event", "details", "price")).to eq(-5_000)
      expect(headers.fetch("replay")).to be_nil
    end

    it "anchors destroy notifications to the surviving sender-side parent when the receiver target is part of a canonical chain" do
      rikki = create(:user, first_name: "Rikki", email: "rikki-canonical@example.com")
      gigi = create(:user, first_name: "Gigi", email: "gigi-canonical@example.com")
      rikki_bank_account = create(:user_bank_account, user: rikki, bank: create(:bank, :random))
      gigi_bank_account = create(:user_bank_account, user: gigi, bank: create(:bank, :random))
      create(:entity, user: rikki, entity_name: "GIGI", entity_user: gigi)
      create(:entity, user: gigi, entity_name: "RIKKI", entity_user: rikki)
      Conversation.create!.tap do |record|
        record.conversation_participants.create!(user: rikki)
        record.conversation_participants.create!(user: gigi)
      end

      source_transaction = described_class.create!(
        user: rikki,
        user_bank_account: rikki_bank_account,
        description: "CANONICAL REIMBURSEMENT",
        price: -5_000,
        date: Date.new(2026, 3, 17),
        month: 3,
        year: 2026,
        category_transactions_attributes: [
          { category_id: rikki.built_in_category("EXCHANGE").id }
        ],
        cash_installments_attributes: [
          { number: 1, price: -5_000, date: Date.new(2026, 3, 17), month: 3, year: 2026 }
        ],
        entity_transactions_attributes: [
          {
            entity_id: rikki.entities.that_are_users.find_by(entity_user: gigi).id,
            is_payer: true,
            price: -5_000,
            price_to_be_returned: -5_000,
            exchanges_count: 1,
            exchanges_attributes: [
              { number: 1, price: -5_000, date: Date.new(2026, 3, 20), month: 3, year: 2026 }
            ]
          }
        ]
      )
      sender_shared_return = create(
        :cash_transaction,
        user: rikki,
        user_bank_account: rikki_bank_account,
        reference_transactable: source_transaction,
        description: "CANONICAL REIMBURSEMENT RETURN",
        price: -5_000,
        date: Date.new(2026, 3, 20),
        month: 3,
        year: 2026,
        category_transactions_attributes: [
          { category_id: rikki.built_in_category("EXCHANGE RETURN").id }
        ],
        cash_installments_attributes: [
          { number: 1, price: -5_000, date: Date.new(2026, 3, 20), month: 3, year: 2026 }
        ]
      )
      receiver_transaction = create(
        :cash_transaction,
        user: gigi,
        user_bank_account: gigi_bank_account,
        reference_transactable: sender_shared_return,
        description: "CANONICAL BORROW RETURN",
        price: 5_000,
        date: Date.new(2026, 3, 20),
        month: 3,
        year: 2026,
        category_transactions_attributes: [
          { category_id: gigi.built_in_category("BORROW RETURN").id }
        ],
        cash_installments_attributes: [
          { number: 1, price: 5_000, date: Date.new(2026, 3, 20), month: 3, year: 2026 }
        ]
      )

      source_transaction.destroy

      message = Message.order(:id).last
      headers = JSON.parse(message.headers)

      expect(message.reference_transactable).to eq(sender_shared_return)
      expect(headers.fetch("event")).to include(
        "action" => "destroy",
        "receiver_first_name" => "Gigi",
        "transaction_type" => "CashTransaction"
      )
      expect(headers.dig("event", "details", "price")).to eq(receiver_transaction.price)
    end

    it "routes derived-context notifications into a matching receiver scenario and auto-creates it when missing" do
      rikki = create(:user, first_name: "Rikki", email: "rikki-derived@example.com")
      gigi = create(:user, first_name: "Gigi", email: "gigi-derived@example.com")
      optimistic = create(:context, user: rikki, source_context: rikki.main_context, name: "Optimistic")
      rikki_bank_account = create(:user_bank_account, user: rikki, bank: create(:bank, :random))
      create(:entity, user: rikki, entity_name: "GIGI", entity_user: gigi)
      gigi_counterpart = create(:entity, user: gigi, entity_name: "RIKKI", entity_user: rikki)

      expect do
        described_class.create!(
          user: rikki,
          context: optimistic,
          user_bank_account: rikki_bank_account,
          description: "SCENARIO LOAN",
          price: 5_000,
          date: Date.new(2026, 3, 17),
          month: 3,
          year: 2026,
          category_transactions_attributes: [
            { category_id: rikki.built_in_category("EXCHANGE").id }
          ],
          cash_installments_attributes: [
            { number: 1, price: 5_000, date: Date.new(2026, 3, 17), month: 3, year: 2026 }
          ],
          entity_transactions_attributes: [
            {
              entity_id: rikki.entities.that_are_users.find_by(entity_user: gigi).id,
              is_payer: true,
              price: -5_000,
              price_to_be_returned: -5_000,
              exchanges_count: 1,
              exchanges_attributes: [
                { number: 1, price: -5_000, date: Date.new(2026, 3, 20), month: 3, year: 2026 }
              ]
            }
          ]
        )
      end.to change { gigi.contexts.count }.by(1)

      receiver_context = gigi.contexts.find_by(scenario_key: optimistic.scenario_key)
      derived_conversation = Conversation.for_users([ rikki.id, gigi.id ]).assistant.for_scenario(optimistic.scenario_key).first

      expect(receiver_context).to be_present
      expect(receiver_context.source_context).to eq(gigi.main_context)
      expect(receiver_context.name).to eq("Optimistic")
      expect(derived_conversation).to be_present
      expect(derived_conversation.messages.last.body).to eq("notification:create")
      expect(Conversation.for_users([ rikki.id, gigi.id ]).assistant.for_scenario(nil)).to be_empty

      headers = JSON.parse(derived_conversation.messages.last.headers)
      expect(headers.fetch("replay")).to include(
        "category_ids" => gigi.built_in_category("EXCHANGE").id,
        "entity_transactions_attributes" => [
          a_hash_including("entity_id" => gigi_counterpart.id)
        ]
      )
    end

    it "reuses the receiver derived context when the scenario already exists" do
      rikki = create(:user, first_name: "Rikki", email: "rikki-reuse@example.com")
      gigi = create(:user, first_name: "Gigi", email: "gigi-reuse@example.com")
      optimistic = create(:context, user: rikki, source_context: rikki.main_context, name: "Optimistic")
      existing_receiver_context = create(
        :context,
        user: gigi,
        source_context: gigi.main_context,
        name: "Optimistic",
        scenario_key: optimistic.scenario_key
      )
      rikki_bank_account = create(:user_bank_account, user: rikki, bank: create(:bank, :random))
      create(:entity, user: rikki, entity_name: "GIGI", entity_user: gigi)
      create(:entity, user: gigi, entity_name: "RIKKI", entity_user: rikki)

      expect do
        described_class.create!(
          user: rikki,
          context: optimistic,
          user_bank_account: rikki_bank_account,
          description: "SCENARIO LOAN",
          price: 5_000,
          date: Date.new(2026, 3, 17),
          month: 3,
          year: 2026,
          category_transactions_attributes: [
            { category_id: rikki.built_in_category("EXCHANGE").id }
          ],
          cash_installments_attributes: [
            { number: 1, price: 5_000, date: Date.new(2026, 3, 17), month: 3, year: 2026 }
          ],
          entity_transactions_attributes: [
            {
              entity_id: rikki.entities.that_are_users.find_by(entity_user: gigi).id,
              is_payer: true,
              price: -5_000,
              price_to_be_returned: -5_000,
              exchanges_count: 1,
              exchanges_attributes: [
                { number: 1, price: -5_000, date: Date.new(2026, 3, 20), month: 3, year: 2026 }
              ]
            }
          ]
        )
      end.not_to(change { gigi.contexts.count })

      conversation = Conversation.for_users([ rikki.id, gigi.id ]).assistant.for_scenario(optimistic.scenario_key).first

      expect(gigi.contexts.find_by(scenario_key: optimistic.scenario_key)).to eq(existing_receiver_context)
      expect(conversation).to be_present
      expect(conversation.messages.last.body).to eq("notification:create")
    end
  end
end

# == Schema Information
#
# Table name: cash_transactions
# Database name: primary
#
#  id                          :bigint           not null, primary key
#  cash_installments_count     :integer          default(0), not null
#  cash_transaction_type       :string
#  comment                     :text
#  date                        :datetime         not null
#  description                 :string           not null
#  imported                    :boolean          default(FALSE)
#  month                       :integer          not null
#  paid                        :boolean          default(FALSE)
#  price                       :integer          not null
#  reference_transactable_type :string           indexed => [reference_transactable_id]
#  starting_price              :integer          not null
#  year                        :integer          not null
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#  context_id                  :bigint           not null, indexed
#  investment_type_id          :bigint           indexed
#  reference_transactable_id   :bigint           indexed => [reference_transactable_type]
#  subscription_id             :bigint           indexed
#  user_bank_account_id        :bigint           indexed
#  user_card_id                :bigint           indexed
#  user_id                     :bigint           not null, indexed
#
# Indexes
#
#  index_cash_transactions_on_context_id              (context_id)
#  index_cash_transactions_on_investment_type_id      (investment_type_id)
#  index_cash_transactions_on_reference_transactable  (reference_transactable_type,reference_transactable_id)
#  index_cash_transactions_on_subscription_id         (subscription_id)
#  index_cash_transactions_on_user_bank_account_id    (user_bank_account_id)
#  index_cash_transactions_on_user_card_id            (user_card_id)
#  index_cash_transactions_on_user_id                 (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (context_id => contexts.id)
#  fk_rails_...  (investment_type_id => investment_types.id)
#  fk_rails_...  (subscription_id => finance_subscriptions.id)
#  fk_rails_...  (user_bank_account_id => user_bank_accounts.id)
#  fk_rails_...  (user_card_id => user_cards.id)
#  fk_rails_...  (user_id => users.id)
#
