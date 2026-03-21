# frozen_string_literal: true

require "rails_helper"

RSpec.describe CashTransaction, type: :model do
  let(:subject) { build(:cash_transaction, :random) }

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
    end
  end

  describe "[ business logic ]" do
    it "recognises exchange return cash transactions by category" do
      exchange_return = subject.user.built_in_category("EXCHANGE RETURN")
      subject.categories << exchange_return
      subject.save

      expect(subject.exchange_return?).to be(true)
    end

    it "builds reimbursement notification headers for cash exchanges when the intent is reimbursement" do
      rikki = create(:user, first_name: "Rikki", email: "rikki@example.com")
      gigi = create(:user, first_name: "Gigi", email: "gigi@example.com")
      rikki_bank_account = create(:user_bank_account, user: rikki, bank: create(:bank, :random))
      create(:entity, user: rikki, entity_name: "GIGI", entity_user: gigi)
      gigi_entity_for_rikki = create(:entity, user: gigi, entity_name: "RIKKI", entity_user: rikki)
      conversation = Conversation.create!.tap do |record|
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
      conversation = Conversation.create!.tap do |record|
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

      create(
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

      headers = JSON.parse(Message.order(:id).last.headers)

      expect(headers).to include("version" => "message_notification_v2")
      expect(headers.fetch("event")).to include(
        "action" => "destroy",
        "receiver_first_name" => "Gigi",
        "transaction_type" => "CashTransaction"
      )
      expect(headers.fetch("replay")).to be_nil
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
#  reference_transactable_type :string           indexed => [reference_transactable_id], uniquely indexed => [reference_transactable_id]
#  starting_price              :integer          not null
#  year                        :integer          not null
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#  investment_type_id          :bigint           indexed
#  reference_transactable_id   :bigint           indexed => [reference_transactable_type], uniquely indexed => [reference_transactable_type]
#  subscription_id             :bigint           indexed
#  user_bank_account_id        :bigint           indexed
#  user_card_id                :bigint           indexed
#  user_id                     :bigint           not null, indexed
#
# Indexes
#
#  index_cash_transactions_on_investment_type_id       (investment_type_id)
#  index_cash_transactions_on_reference_transactable   (reference_transactable_type,reference_transactable_id)
#  index_cash_transactions_on_subscription_id          (subscription_id)
#  index_cash_transactions_on_user_bank_account_id     (user_bank_account_id)
#  index_cash_transactions_on_user_card_id             (user_card_id)
#  index_cash_transactions_on_user_id                  (user_id)
#  index_reference_transactable_on_cash_composite_key  (reference_transactable_type,reference_transactable_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (investment_type_id => investment_types.id)
#  fk_rails_...  (subscription_id => finance_subscriptions.id)
#  fk_rails_...  (user_bank_account_id => user_bank_accounts.id)
#  fk_rails_...  (user_card_id => user_cards.id)
#  fk_rails_...  (user_id => users.id)
#
