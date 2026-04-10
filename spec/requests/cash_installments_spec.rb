# frozen_string_literal: true

require "rails_helper"

RSpec.describe "CashInstallments", type: :request do
  let(:user) { create(:user, :random) }
  let(:bank) { create(:bank, :random) }
  let(:user_bank_account) { create(:user_bank_account, :random, user:, bank:) }
  let(:installment_date) { Time.zone.local(2026, 3, 10, 12, 0, 0) }

  around do |example|
    perform_enqueued_jobs { example.run }
  end

  before { sign_in user }

  def switch_to_context!(context)
    patch switch_context_path(context)
    expect(response).to redirect_to(root_path)
  end

  def create_shared_return_pair(sender:, receiver:, sender_context: sender.main_context, receiver_context: receiver.main_context, link_reference: true) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
    sender.entities.find_or_create_by!(entity_name: receiver.first_name.upcase) { |entity_record| entity_record.entity_user = receiver }
    receiver_counterpart = receiver.entities.find_or_create_by!(entity_name: sender.first_name.upcase) { |entity_record| entity_record.entity_user = sender }
    sender_bank_account = create(:user_bank_account, user: sender, bank: create(:bank, :random))
    receiver_bank_account = create(:user_bank_account, user: receiver, bank: create(:bank, :random))

    sender_transaction = create(
      :cash_transaction,
      user: sender,
      context: sender_context,
      user_bank_account: sender_bank_account,
      description: "Shared return",
      date: installment_date,
      month: 3,
      year: 2026,
      price: -1_000,
      category_transactions_attributes: [
        { category_id: sender.built_in_category("EXCHANGE RETURN").id }
      ],
      entity_transactions_attributes: [
        { entity_id: sender.entities.that_are_users.find_by(entity_user: receiver).id, is_payer: false, price: 0, price_to_be_returned: 0 }
      ],
      cash_installments_attributes: [
        { number: 1, date: installment_date, month: 3, year: 2026, price: -1_000, paid: false }
      ]
    )
    sender_transaction.cash_installments.destroy_all
    sender_transaction.cash_installments.create!(number: 1, date: installment_date, month: 3, year: 2026, price: -1_000, paid: false)
    sender_transaction.update_column(:cash_installments_count, 1)

    receiver_transaction = create(
      :cash_transaction,
      user: receiver,
      context: receiver_context,
      user_bank_account: receiver_bank_account,
      reference_transactable: (sender_transaction if link_reference),
      description: "Shared return",
      date: installment_date,
      month: 3,
      year: 2026,
      price: -1_000,
      category_transactions_attributes: [
        { category_id: receiver.built_in_category("BORROW RETURN").id }
      ],
      entity_transactions_attributes: [
        { entity_id: receiver_counterpart.id, is_payer: false, price: 0, price_to_be_returned: 0 }
      ],
      cash_installments_attributes: [
        { number: 1, date: installment_date, month: 3, year: 2026, price: -1_000, paid: false }
      ]
    )
    receiver_transaction.cash_installments.destroy_all
    receiver_transaction.cash_installments.create!(number: 1, date: installment_date, month: 3, year: 2026, price: -1_000, paid: false)
    receiver_transaction.update_column(:cash_installments_count, 1)

    [ sender_transaction, receiver_transaction ]
  end

  def create_card_origin_shared_return_bundle(sender:, receiver:, sender_context: sender.main_context, receiver_context: receiver.main_context) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
    sender_entity_for_receiver =
      sender.entities.find_or_create_by!(entity_name: receiver.first_name.upcase) do |entity_record|
        entity_record.entity_user = receiver
      end
    receiver_entity_for_sender =
      receiver.entities.find_or_create_by!(entity_name: sender.first_name.upcase) do |entity_record|
        entity_record.entity_user = sender
      end

    sender_card = create(:card, :random, bank: create(:bank, :random))
    sender_user_card = create(:user_card, :random, user: sender, card: sender_card)
    receiver_bank_account = create(:user_bank_account, user: receiver, bank: create(:bank, :random))

    origin_card_transaction = create(
      :card_transaction,
      user: sender,
      context: sender_context,
      user_card: sender_user_card,
      description: "Card mirror source",
      date: Date.new(2026, 3, 15),
      month: 4,
      year: 2026,
      price: -2_000
    )
    origin_card_transaction.category_transactions.destroy_all
    origin_card_transaction.category_transactions.create!(category: sender.built_in_category("EXCHANGE"))
    payer_entity_transaction = origin_card_transaction.entity_transactions.first
    payer_entity_transaction.update!(
      entity_id: sender_entity_for_receiver.id,
      is_payer: true,
      price: -2_000,
      price_to_be_returned: -2_000,
      exchanges_count: 2
    )

    first_exchange = create(
      :exchange,
      entity_transaction: payer_entity_transaction,
      bound_type: :card_bound,
      exchange_type: :monetary,
      number: 1,
      price: -1_000,
      date: Date.new(2026, 3, 20),
      month: 3,
      year: 2026
    )
    create(
      :exchange,
      entity_transaction: payer_entity_transaction,
      bound_type: :card_bound,
      exchange_type: :monetary,
      number: 2,
      price: -1_000,
      date: Date.new(2026, 4, 20),
      month: 4,
      year: 2026
    )

    sender_shared_return = first_exchange.cash_transaction.reload
    sender_shared_return.cash_installments.destroy_all
    sender_shared_return.cash_installments.create!(number: 1, date: Date.new(2026, 3, 20), month: 3, year: 2026, price: -1_000, paid: false)
    sender_shared_return.cash_installments.create!(number: 2, date: Date.new(2026, 4, 20), month: 4, year: 2026, price: -1_000, paid: false)
    sender_shared_return.update_column(:cash_installments_count, 2)
    receiver_shared_return = create(
      :cash_transaction,
      user: receiver,
      context: receiver_context,
      user_bank_account: receiver_bank_account,
      reference_transactable: sender_shared_return,
      description: sender_shared_return.description,
      date: Date.new(2026, 3, 20),
      month: 3,
      year: 2026,
      price: -2_000,
      category_transactions_attributes: [
        { category_id: receiver.built_in_category("BORROW RETURN").id }
      ],
      entity_transactions_attributes: [
        { entity_id: receiver_entity_for_sender.id, is_payer: false, price: 0, price_to_be_returned: 0 }
      ],
      cash_installments_attributes: [
        { number: 1, date: Date.new(2026, 3, 20), month: 3, year: 2026, price: -1_000, paid: false },
        { number: 2, date: Date.new(2026, 4, 20), month: 4, year: 2026, price: -1_000, paid: false }
      ]
    )
    receiver_shared_return.cash_installments.destroy_all
    receiver_shared_return.cash_installments.create!(number: 1, date: Date.new(2026, 3, 20), month: 3, year: 2026, price: -1_000, paid: false)
    receiver_shared_return.cash_installments.create!(number: 2, date: Date.new(2026, 4, 20), month: 4, year: 2026, price: -1_000, paid: false)
    receiver_shared_return.update_column(:cash_installments_count, 2)

    [ origin_card_transaction.reload, sender_shared_return.reload, receiver_shared_return.reload ]
  end

  def create_reimbursement_shared_return_bundle(sender:, receiver:, sender_context: sender.main_context, receiver_context: receiver.main_context) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
    sender_entity_for_receiver =
      sender.entities.find_or_create_by!(entity_name: receiver.first_name.upcase) do |entity_record|
        entity_record.entity_user = receiver
      end
    receiver_entity_for_sender =
      receiver.entities.find_or_create_by!(entity_name: sender.first_name.upcase) do |entity_record|
        entity_record.entity_user = sender
      end

    sender_bank_account = create(:user_bank_account, user: sender, bank: create(:bank, :random))
    receiver_bank_account = create(:user_bank_account, user: receiver, bank: create(:bank, :random))

    origin_cash_transaction = create(
      :cash_transaction,
      user: sender,
      context: sender_context,
      user_bank_account: sender_bank_account,
      description: "Reimbursement source",
      date: Date.new(2026, 3, 18),
      month: 3,
      year: 2026,
      price: -2_000,
      category_transactions_attributes: [
        { category_id: sender.built_in_category("EXCHANGE").id }
      ],
      entity_transactions_attributes: [
        { entity_id: sender_entity_for_receiver.id, is_payer: true, price: -2_000, price_to_be_returned: -2_000 }
      ],
      cash_installments_attributes: [
        { number: 1, date: Date.new(2026, 3, 18), month: 3, year: 2026, price: -2_000, paid: false }
      ]
    )

    sender_shared_return = create(
      :cash_transaction,
      user: sender,
      context: sender_context,
      user_bank_account: sender_bank_account,
      reference_transactable: origin_cash_transaction,
      description: "Reimbursement return",
      date: Date.new(2026, 3, 20),
      month: 3,
      year: 2026,
      price: -2_000,
      category_transactions_attributes: [
        { category_id: sender.built_in_category("EXCHANGE RETURN").id }
      ],
      entity_transactions_attributes: [
        { entity_id: sender_entity_for_receiver.id, is_payer: false, price: 0, price_to_be_returned: 0 }
      ],
      cash_installments_attributes: [
        { number: 1, date: Date.new(2026, 3, 20), month: 3, year: 2026, price: -1_000, paid: false },
        { number: 2, date: Date.new(2026, 4, 20), month: 4, year: 2026, price: -1_000, paid: false }
      ]
    )
    sender_shared_return.cash_installments.destroy_all
    sender_shared_return.cash_installments.create!(number: 1, date: Date.new(2026, 3, 20), month: 3, year: 2026, price: -1_000, paid: false)
    sender_shared_return.cash_installments.create!(number: 2, date: Date.new(2026, 4, 20), month: 4, year: 2026, price: -1_000, paid: false)
    sender_shared_return.update_column(:cash_installments_count, 2)

    payer_entity_transaction = origin_cash_transaction.entity_transactions.first
    create(
      :exchange,
      entity_transaction: payer_entity_transaction,
      cash_transaction: sender_shared_return,
      bound_type: :standalone,
      exchange_type: :monetary,
      number: 1,
      price: -1_000,
      date: Date.new(2026, 3, 20),
      month: 3,
      year: 2026
    )
    create(
      :exchange,
      entity_transaction: payer_entity_transaction,
      cash_transaction: sender_shared_return,
      bound_type: :standalone,
      exchange_type: :monetary,
      number: 2,
      price: -1_000,
      date: Date.new(2026, 4, 20),
      month: 4,
      year: 2026
    )

    receiver_shared_return = create(
      :cash_transaction,
      user: receiver,
      context: receiver_context,
      user_bank_account: receiver_bank_account,
      reference_transactable: sender_shared_return,
      description: sender_shared_return.description,
      date: Date.new(2026, 3, 20),
      month: 3,
      year: 2026,
      price: -2_000,
      category_transactions_attributes: [
        { category_id: receiver.built_in_category("BORROW RETURN").id }
      ],
      entity_transactions_attributes: [
        { entity_id: receiver_entity_for_sender.id, is_payer: false, price: 0, price_to_be_returned: 0 }
      ],
      cash_installments_attributes: [
        { number: 1, date: Date.new(2026, 3, 20), month: 3, year: 2026, price: -1_000, paid: false },
        { number: 2, date: Date.new(2026, 4, 20), month: 4, year: 2026, price: -1_000, paid: false }
      ]
    )
    receiver_shared_return.cash_installments.destroy_all
    receiver_shared_return.cash_installments.create!(number: 1, date: Date.new(2026, 3, 20), month: 3, year: 2026, price: -1_000, paid: false)
    receiver_shared_return.cash_installments.create!(number: 2, date: Date.new(2026, 4, 20), month: 4, year: 2026, price: -1_000, paid: false)
    receiver_shared_return.update_column(:cash_installments_count, 2)

    [ origin_cash_transaction.reload, sender_shared_return.reload, receiver_shared_return.reload ]
  end

  describe "[ #pay ]" do
    it "marks the installment as paid and splits the remainder when the paid amount is smaller" do
      cash_transaction = create(
        :cash_transaction,
        user:,
        user_bank_account:,
        date: installment_date,
        month: 3,
        year: 2026,
        price: 1000,
        cash_installments: [
          build(
            :cash_installment,
            number: 1,
            date: installment_date,
            month: 3,
            year: 2026,
            price: 1000,
            paid: false
          )
        ]
      )
      cash_installment = cash_transaction.cash_installments.first

      expect do
        patch pay_cash_installment_path(cash_installment), params: {
          cash_installment: {
            date: Time.zone.local(2026, 3, 12, 12, 0, 0).strftime("%Y-%m-%dT%H:%M"),
            price: 600
          }
        }, headers: turbo_stream_headers
      end.to change(CashInstallment, :count).by(1)

      cash_installment.reload
      remainder = cash_transaction.cash_installments.where.not(id: cash_installment.id).order(:number).last

      expect(cash_installment).to be_paid
      expect(cash_installment.price).to eq(600)
      expect(cash_installment.date.to_date).to eq(Date.new(2026, 3, 12))
      expect(remainder.price).to eq(400)
      expect(remainder.date.to_date).to eq(Date.new(2026, 3, 11))
    end

    it "mirrors the split settlement back to card-bound exchange rows" do
      card_transaction = create(
        :card_transaction,
        user:,
        context: user.main_context,
        user_card: create(:user_card, :random, user:, card: create(:card, :random, bank: bank)),
        description: "Mirror source",
        date: Date.new(2026, 3, 10),
        month: 4,
        year: 2026,
        price: -3_000
      )
      card_transaction.category_transactions.destroy_all
      card_transaction.category_transactions.create!(category: user.built_in_category("EXCHANGE"))
      entity_transaction = card_transaction.entity_transactions.first
      entity_transaction.update!(price: -3_000, price_to_be_returned: -3_000, is_payer: true, exchanges_count: 3)
      first_exchange = create(:exchange, entity_transaction:, bound_type: :card_bound, exchange_type: :monetary, number: 1, price: -1_000,
                                         date: Date.new(2026, 4, 10), month: 4, year: 2026)
      create(:exchange, entity_transaction:, bound_type: :card_bound, exchange_type: :monetary, number: 2, price: -1_000, date: Date.new(2026, 4, 11), month: 4,
                        year: 2026)
      create(:exchange, entity_transaction:, bound_type: :card_bound, exchange_type: :monetary, number: 3, price: -1_000, date: Date.new(2026, 4, 12), month: 4,
                        year: 2026)

      installment = first_exchange.cash_transaction.reload.cash_installments.find_by!(number: 1)

      patch pay_cash_installment_path(installment), params: {
        cash_installment: {
          date: Time.zone.local(2026, 3, 26, 17, 0, 0).strftime("%Y-%m-%dT%H:%M"),
          price: -500
        }
      }, headers: turbo_stream_headers

      expect(response).to have_http_status(:ok)
      exchange_return = first_exchange.cash_transaction.reload
      due_day = [ card_transaction.user_card.due_date_day, Time.days_in_month(4, 2026) ].min
      expected_due_date = Time.zone.local(2026, 4, due_day).end_of_day.change(usec: 999_999)

      expect(exchange_return.cash_installments.order(:number).pluck(:number, :date, :month, :year, :price)).to eq(
        [
          [ 1, Time.zone.local(2026, 3, 26, 17, 0, 0), 3, 2026, -500 ],
          [ 2, expected_due_date, 4, 2026, -2_500 ]
        ]
      )
      expect(entity_transaction.reload.exchanges.order(:number).pluck(:number, :date, :month, :year, :price)).to eq(
        [
          [ 1, Time.zone.local(2026, 3, 26, 17, 0, 0), 3, 2026, -500 ],
          [ 2, expected_due_date, 4, 2026, -2_500 ]
        ]
      )
    end

    it "synchronizes paid state to the counterpart shared return and informs via assistant message" do
      sender = user
      receiver = create(:user, :random)
      sender_transaction, receiver_transaction = create_shared_return_pair(sender:, receiver:)
      paid_at = Time.zone.local(2026, 3, 12, 12, 0, 0)

      patch pay_cash_installment_path(sender_transaction.cash_installments.first), params: {
        cash_installment: {
          date: paid_at.strftime("%Y-%m-%dT%H:%M"),
          price: -1_000
        }
      }, headers: turbo_stream_headers

      conversation = Conversation.for_users([ sender.id, receiver.id ]).assistant.order(:id).last
      message = conversation.messages.order(:id).last

      expect(response).to have_http_status(:ok)
      expect(sender_transaction.cash_installments.first.reload).to be_paid
      expect(receiver_transaction.cash_installments.first.reload).to be_paid
      expect(receiver_transaction.cash_installments.first.date).to eq(paid_at)
      expect(receiver_transaction.cash_installments.first.month).to eq(3)
      expect(receiver_transaction.cash_installments.first.year).to eq(2026)
      expect(message.body).to eq("notification:paid_state")
      expect(JSON.parse(message.headers)).to include(
        "version" => "message_paid_state_v1",
        "event" => include("action" => "paid")
      )
    end

    it "does not synchronize paid state for a manually created counterpart pair without explicit linkage" do
      sender = user
      receiver = create(:user, :random)
      sender_transaction, receiver_transaction = create_shared_return_pair(sender:, receiver:, link_reference: false)
      paid_at = Time.zone.local(2026, 3, 12, 12, 0, 0)

      patch pay_cash_installment_path(sender_transaction.cash_installments.first), params: {
        cash_installment: {
          date: paid_at.strftime("%Y-%m-%dT%H:%M"),
          price: -1_000
        }
      }, headers: turbo_stream_headers

      expect(response).to have_http_status(:ok)
      expect(sender_transaction.cash_installments.first.reload).to be_paid
      expect(receiver_transaction.cash_installments.first.reload).not_to be_paid
      expect(receiver_transaction.cash_installments.first.date).to eq(installment_date)
      expect(Conversation.for_users([ sender.id, receiver.id ]).assistant).to be_empty
    end

    it "synchronizes paid state inside the matching derived scenario only" do
      sender = user
      receiver = create(:user, :random)
      sender_derived = Logic::ContextCloneService.new(source_context: sender.main_context, name: "Sender Shared Paid State", scenario_key: "shared-paid-state").call
      receiver_derived = Logic::ContextCloneService.new(source_context: receiver.main_context, name: "Receiver Shared Paid State",
                                                        scenario_key: "shared-paid-state").call

      sender_transaction, receiver_transaction = create_shared_return_pair(
        sender:,
        receiver:,
        sender_context: sender_derived,
        receiver_context: receiver_derived
      )
      paid_at = Time.zone.local(2026, 3, 12, 12, 0, 0)

      main_sender_transaction, main_receiver_transaction = create_shared_return_pair(sender:, receiver:)

      switch_to_context!(sender_derived)

      patch pay_cash_installment_path(sender_transaction.cash_installments.first), params: {
        cash_installment: {
          date: paid_at.strftime("%Y-%m-%dT%H:%M"),
          price: -1_000
        }
      }, headers: turbo_stream_headers

      conversation = Conversation.for_users([ sender.id, receiver.id ]).assistant.for_scenario(sender_derived.scenario_key).order(:id).last
      message = conversation.messages.order(:id).last

      expect(response).to have_http_status(:ok)
      expect(sender_transaction.cash_installments.first.reload).to be_paid
      expect(receiver_transaction.cash_installments.first.reload).to be_paid
      expect(receiver_transaction.cash_installments.first.date).to eq(paid_at)
      expect(main_sender_transaction.cash_installments.first.reload).not_to be_paid
      expect(main_receiver_transaction.cash_installments.first.reload).not_to be_paid
      expect(conversation).to be_present
      expect(message.body).to eq("notification:paid_state")
      expect(message.conversation.scenario_key).to eq(sender_derived.scenario_key)
      expect(JSON.parse(message.headers)).to include(
        "version" => "message_paid_state_v1",
        "event" => include("action" => "paid")
      )
    end

    it "keeps the payment local when the counterpart shared return cannot be resolved" do
      sender = user
      receiver = create(:user, :random)
      sender_transaction, receiver_transaction = create_shared_return_pair(sender:, receiver:, link_reference: false)
      receiver_transaction.update_columns(price: -2_000, starting_price: -2_000)
      receiver_transaction.cash_installments.first.update_columns(price: -2_000)
      Conversation.find_or_create_assistant_between!(sender, receiver).messages.create!(
        user: sender,
        reference_transactable: sender_transaction,
        body: "notification:update",
        headers: {
          version: "message_notification_v2",
          event: {
            action: "update",
            receiver_first_name: receiver.first_name,
            transaction_type: "CashTransaction",
            details: { description: sender_transaction.description }
          },
          replay: { id: sender_transaction.id, type: "CashTransaction" }
        }.to_json
      )

      patch pay_cash_installment_path(sender_transaction.cash_installments.first), params: {
        cash_installment: {
          date: installment_date.strftime("%Y-%m-%dT%H:%M"),
          price: -1_000
        }
      }, headers: turbo_stream_headers

      expect(response).to have_http_status(:ok)
      expect(sender_transaction.cash_installments.first.reload).to be_paid
      expect(receiver_transaction.cash_installments.first.reload).not_to be_paid
      expect(Message.where(body: "notification:paid_state")).to be_empty
    end

    it "sends an actionable update instead of a paid-state sync when partial pay changes the shared return structure" do
      sender = user
      receiver = create(:user, :random)
      sender_transaction, receiver_transaction = create_shared_return_pair(sender:, receiver:)
      sender_transaction.cash_installments.destroy_all
      sender_transaction.cash_installments.create!(number: 1, date: installment_date, month: 3, year: 2026, price: -3_000, paid: false)
      sender_transaction.cash_installments.create!(number: 2, date: installment_date.next_month, month: 4, year: 2026, price: -3_000, paid: false)
      sender_transaction.update_columns(cash_installments_count: 2, price: -6_000, starting_price: -6_000)
      receiver_transaction.cash_installments.destroy_all
      receiver_transaction.cash_installments.create!(number: 1, date: installment_date, month: 3, year: 2026, price: -3_000, paid: false)
      receiver_transaction.cash_installments.create!(number: 2, date: installment_date.next_month, month: 4, year: 2026, price: -3_000, paid: false)
      receiver_transaction.update_columns(cash_installments_count: 2, price: -6_000, starting_price: -6_000)
      conversation = Conversation.find_or_create_assistant_between!(sender, receiver)

      patch pay_cash_installment_path(sender_transaction.cash_installments.find_by!(number: 1)), params: {
        cash_installment: {
          date: installment_date.strftime("%Y-%m-%dT%H:%M"),
          price: -2_000
        }
      }, headers: turbo_stream_headers

      message = conversation.messages.order(:id).last
      replay = JSON.parse(message.headers).fetch("replay")

      expect(response).to have_http_status(:ok)
      expect(sender_transaction.cash_installments.order(:number).pluck(:price, :paid)).to eq([ [ -2_000, true ], [ -1_000, false ], [ -3_000, false ] ])
      expect(receiver_transaction.cash_installments.order(:number).pluck(:price, :paid)).to eq([ [ -3_000, false ], [ -3_000, false ] ])
      expect(message.body).to eq("notification:update")
      expect(Message.where(body: "notification:paid_state")).to be_empty
      expect(replay.fetch("cash_installments_attributes")).to include(
        a_hash_including("number" => 1, "price" => -2_000, "paid" => true),
        a_hash_including("number" => 2, "price" => -1_000, "paid" => false),
        a_hash_including("number" => 3, "price" => -3_000, "paid" => false)
      )
    end

    it "reflects paid state on card-bound exchanges without rewriting their own dates" do
      card_transaction = create(
        :card_transaction,
        user:,
        context: user.main_context,
        user_card: create(:user_card, :random, user:, card: create(:card, :random, bank: bank)),
        description: "Mirror source",
        date: Date.new(2026, 3, 10),
        month: 4,
        year: 2026,
        price: -2_000
      )
      card_transaction.category_transactions.destroy_all
      card_transaction.category_transactions.create!(category: user.built_in_category("EXCHANGE"))
      entity_transaction = card_transaction.entity_transactions.first
      entity_transaction.update!(price: -2_000, price_to_be_returned: -2_000, is_payer: true, exchanges_count: 2)
      first_exchange = create(:exchange, entity_transaction:, bound_type: :card_bound, exchange_type: :monetary, number: 1, price: -1_000,
                                         date: Date.new(2026, 3, 20), month: 3, year: 2026)
      second_exchange = create(:exchange, entity_transaction:, bound_type: :card_bound, exchange_type: :monetary, number: 2, price: -1_000,
                                          date: Date.new(2026, 3, 21), month: 3, year: 2026)

      exchange_return = first_exchange.cash_transaction.reload
      installment = exchange_return.cash_installments.find_by!(number: 1)

      paid_at = Time.zone.parse("2026-03-26 17:00")

      patch pay_cash_installment_path(installment), params: {
        cash_installment: {
          date: paid_at.strftime("%Y-%m-%dT%H:%M"),
          price: installment.price
        }
      }, headers: turbo_stream_headers

      expect(response).to have_http_status(:ok)
      expect(first_exchange.reload.mirrored_paid?).to be(true)
      expect(second_exchange.reload.mirrored_paid?).to be(true)
      expect(first_exchange.date.to_date).to eq(Date.new(2026, 3, 20))
      expect(first_exchange.month).to eq(3)
      expect(first_exchange.year).to eq(2026)
      expect(entity_transaction.reload.status).to eq("finished")
    end

    it "anchors partial-pay structural update messages to the canonical card transaction" do
      origin_card_transaction, sender_shared_return, receiver_shared_return = create_card_origin_shared_return_bundle(sender: user, receiver: create(:user, :random))
      sender_shared_return.cash_installments.destroy_all
      sender_shared_return.cash_installments.create!(number: 1, date: Date.new(2026, 3, 20), month: 3, year: 2026, price: -3_000, paid: false)
      sender_shared_return.cash_installments.create!(number: 2, date: Date.new(2026, 4, 20), month: 4, year: 2026, price: -3_000, paid: false)
      sender_shared_return.update_columns(cash_installments_count: 2, price: -6_000, starting_price: -6_000)
      receiver_shared_return.cash_installments.destroy_all
      receiver_shared_return.cash_installments.create!(number: 1, date: Date.new(2026, 3, 20), month: 3, year: 2026, price: -3_000, paid: false)
      receiver_shared_return.cash_installments.create!(number: 2, date: Date.new(2026, 4, 20), month: 4, year: 2026, price: -3_000, paid: false)
      receiver_shared_return.update_columns(cash_installments_count: 2, price: -6_000, starting_price: -6_000)
      conversation = Conversation.find_or_create_assistant_between!(user, receiver_shared_return.user)

      patch pay_cash_installment_path(sender_shared_return.cash_installments.find_by!(number: 1)), params: {
        cash_installment: {
          date: Date.new(2026, 3, 20).strftime("%Y-%m-%dT%H:%M"),
          price: -2_000
        }
      }, headers: turbo_stream_headers

      message = conversation.messages.order(:id).last
      replay = message.replay_payload

      expect(response).to have_http_status(:ok)
      expect(message.body).to eq("notification:update")
      expect(message.reference_transactable).to eq(origin_card_transaction)
      expect(replay.fetch("type")).to eq("CardTransaction")
      expect(replay.fetch("id")).to eq(origin_card_transaction.id)
    end

    context "with mirror exchange flows between entity users" do
      it "synchronizes paid state from a card-origin shared return to the counterpart borrow return" do
        sender = user
        receiver = create(:user, :random)
        _origin_card_transaction, sender_shared_return, receiver_shared_return =
          create_card_origin_shared_return_bundle(sender:, receiver:)
        paid_at = Time.zone.local(2026, 3, 25, 11, 30, 0)

        patch pay_cash_installment_path(sender_shared_return.cash_installments.find_by!(number: 1)), params: {
          cash_installment: {
            date: paid_at.strftime("%Y-%m-%dT%H:%M"),
            price: -1_000
          }
        }, headers: turbo_stream_headers

        assistant_conversation = Conversation.for_users([ sender.id, receiver.id ]).assistant.order(:id).last
        message = assistant_conversation.messages.order(:id).last

        expect(response).to have_http_status(:ok)
        expect(sender_shared_return.cash_installments.find_by!(number: 1).reload).to be_paid
        expect(receiver_shared_return.cash_installments.find_by!(number: 1).reload).to be_paid
        expect(receiver_shared_return.cash_installments.find_by!(number: 2).reload).not_to be_paid
        expect(receiver_shared_return.cash_installments.find_by!(number: 1).date).to eq(paid_at)
        expect(message.body).to eq("notification:paid_state")
        expect(message.applied_at).to be_nil
        expect(JSON.parse(message.headers)).to include(
          "version" => "message_paid_state_v1",
          "event" => include("action" => "paid")
        )
      end

      it "keeps paid state local when only older same-shape borrow returns exist without a chain" do
        sender = user
        receiver = create(:user, :random)
        sender_shared_return, receiver_shared_return = create_shared_return_pair(sender:, receiver:, link_reference: false)
        receiver_counterpart = receiver.entities.find_by!(entity_user: sender)

        stale_old_return = create(
          :cash_transaction,
          user: receiver,
          context: receiver.main_context,
          user_bank_account: create(:user_bank_account, user: receiver, bank: create(:bank, :random)),
          description: "Shared return",
          date: Date.new(2025, 11, 10),
          month: 11,
          year: 2025,
          price: -1_000,
          category_transactions_attributes: [
            { category_id: receiver.built_in_category("BORROW RETURN").id }
          ],
          entity_transactions_attributes: [
            { entity_id: receiver_counterpart.id, is_payer: false, price: 0, price_to_be_returned: 0 }
          ],
          cash_installments_attributes: [
            { number: 1, date: Date.new(2025, 11, 10), month: 11, year: 2025, price: -1_000, paid: true }
          ]
        )
        stale_old_return.cash_installments.destroy_all
        stale_old_return.cash_installments.create!(number: 1, date: Date.new(2025, 11, 10), month: 11, year: 2025, price: -1_000, paid: true)
        stale_old_return.update_columns(cash_installments_count: 1, created_at: Time.zone.local(2025, 11, 10, 12, 0, 0))
        sender_shared_return.update_column(:created_at, Time.zone.local(2026, 3, 10, 12, 0, 0))
        receiver_shared_return.update_column(:created_at, Time.zone.local(2026, 3, 10, 12, 5, 0))

        patch pay_cash_installment_path(sender_shared_return.cash_installments.find_by!(number: 1)), params: {
          cash_installment: {
            date: Time.zone.local(2026, 3, 25, 11, 30, 0).strftime("%Y-%m-%dT%H:%M"),
            price: -1_000
          }
        }, headers: turbo_stream_headers

        expect(response).to have_http_status(:ok)
        expect(sender_shared_return.cash_installments.find_by!(number: 1).reload).to be_paid
        expect(receiver_shared_return.cash_installments.find_by!(number: 1).reload).not_to be_paid
        expect(stale_old_return.cash_installments.find_by!(number: 1).reload).to be_paid
        expect(stale_old_return.cash_installments.find_by!(number: 1).date.to_date).to eq(Date.new(2025, 11, 10))
      end

      it "synchronizes multiple paid installments from the counterpart borrow return back to the card-origin shared return" do
        sender = user
        receiver = create(:user, :random)
        _origin_card_transaction, sender_shared_return, receiver_shared_return =
          create_card_origin_shared_return_bundle(sender:, receiver:)
        paid_at = Time.zone.local(2026, 4, 25, 10, 15, 0)

        sign_out sender
        sign_in receiver

        receiver_shared_return.cash_installments.order(:number).each do |installment|
          patch pay_cash_installment_path(installment), params: {
            cash_installment: {
              date: paid_at.strftime("%Y-%m-%dT%H:%M"),
              price: installment.price
            }
          }, headers: turbo_stream_headers

          expect(response).to have_http_status(:ok)
        end

        assistant_conversation = Conversation.for_users([ sender.id, receiver.id ]).assistant.order(:id).last
        paid_state_messages = assistant_conversation.messages.where(body: "notification:paid_state").order(:id)

        expect(sender_shared_return.cash_installments.find_by!(number: 1).reload).to be_paid
        expect(sender_shared_return.cash_installments.find_by!(number: 2).reload).to be_paid
        expect(paid_state_messages.count).to eq(2)
        expect(paid_state_messages.pluck(:applied_at)).to all(be_nil)
      end

      it "keeps the reimbursement source transaction untouched while syncing the shared return pair" do
        sender = user
        receiver = create(:user, :random)
        origin_cash_transaction, sender_shared_return, receiver_shared_return =
          create_reimbursement_shared_return_bundle(sender:, receiver:)
        paid_at = Time.zone.local(2026, 3, 27, 9, 45, 0)

        patch pay_cash_installment_path(sender_shared_return.cash_installments.find_by!(number: 1)), params: {
          cash_installment: {
            date: paid_at.strftime("%Y-%m-%dT%H:%M"),
            price: -1_000
          }
        }, headers: turbo_stream_headers

        assistant_conversation = Conversation.for_users([ sender.id, receiver.id ]).assistant.order(:id).last
        message = assistant_conversation.messages.order(:id).last

        expect(response).to have_http_status(:ok)
        expect(sender_shared_return.cash_installments.find_by!(number: 1).reload).to be_paid
        expect(receiver_shared_return.cash_installments.find_by!(number: 1).reload).to be_paid
        expect(origin_cash_transaction.cash_installments.find_by!(number: 1).reload).not_to be_paid
        expect(message.body).to eq("notification:paid_state")
        expect(message.applied_at).to be_nil
      end

      it "synchronizes a borrow return installment to the counterpart exchange return and not to the source reimbursement transaction" do
        sender = create(:user, :random)
        receiver = user
        origin_cash_transaction, sender_shared_return, receiver_shared_return =
          create_reimbursement_shared_return_bundle(sender:, receiver:)
        paid_at = Time.zone.local(2026, 3, 28, 14, 10, 0)

        patch pay_cash_installment_path(receiver_shared_return.cash_installments.find_by!(number: 1)), params: {
          cash_installment: {
            date: paid_at.strftime("%Y-%m-%dT%H:%M"),
            price: -1_000
          }
        }, headers: turbo_stream_headers

        assistant_conversation = Conversation.for_users([ sender.id, receiver.id ]).assistant.order(:id).last
        message = assistant_conversation.messages.order(:id).last

        expect(response).to have_http_status(:ok)
        expect(receiver_shared_return.cash_installments.find_by!(number: 1).reload).to be_paid
        expect(sender_shared_return.cash_installments.find_by!(number: 1).reload).to be_paid
        expect(origin_cash_transaction.cash_installments.find_by!(number: 1).reload).not_to be_paid
        expect(origin_cash_transaction.reload).not_to be_paid
        expect(sender_shared_return.reload).not_to be_paid
        expect(message.body).to eq("notification:paid_state")
        expect(message.applied_at).to be_nil
      end

      it "keeps the reimbursement source transaction untouched when the counterpart user pays multiple installments" do
        sender = user
        receiver = create(:user, :random)
        origin_cash_transaction, sender_shared_return, receiver_shared_return =
          create_reimbursement_shared_return_bundle(sender:, receiver:)
        paid_at = Time.zone.local(2026, 4, 27, 9, 45, 0)

        sign_out sender
        sign_in receiver

        receiver_shared_return.cash_installments.order(:number).each do |installment|
          patch pay_cash_installment_path(installment), params: {
            cash_installment: {
              date: paid_at.strftime("%Y-%m-%dT%H:%M"),
              price: installment.price
            }
          }, headers: turbo_stream_headers

          expect(response).to have_http_status(:ok)
        end

        assistant_conversation = Conversation.for_users([ sender.id, receiver.id ]).assistant.order(:id).last
        paid_state_messages = assistant_conversation.messages.where(body: "notification:paid_state").order(:id)

        expect(sender_shared_return.cash_installments.find_by!(number: 1).reload).to be_paid
        expect(sender_shared_return.cash_installments.find_by!(number: 2).reload).to be_paid
        expect(origin_cash_transaction.cash_installments.find_by!(number: 1).reload).not_to be_paid
        expect(paid_state_messages.count).to eq(2)
        expect(paid_state_messages.pluck(:applied_at)).to all(be_nil)
      end
    end
  end

  describe "[ #pay_multiple ]" do
    it "marks all selected installments as paid with the chosen date" do
      first = create(
        :cash_transaction,
        user:,
        user_bank_account:,
        date: installment_date,
        month: 3,
        year: 2026,
        cash_installments: [ build(:cash_installment, number: 1, date: installment_date, month: 3, year: 2026, price: 500, paid: false) ]
      ).cash_installments.first
      second = create(
        :cash_transaction,
        user:,
        user_bank_account:,
        date: installment_date + 1.day,
        month: 3,
        year: 2026,
        cash_installments: [ build(:cash_installment, number: 1, date: installment_date + 1.day, month: 3, year: 2026, price: 700, paid: false) ]
      ).cash_installments.first

      post pay_multiple_cash_installments_path, params: {
        ids: [ first.id, second.id ],
        cash_installment: {
          date: Time.zone.local(2026, 3, 20, 10, 0, 0).strftime("%Y-%m-%dT%H:%M")
        }
      }, headers: turbo_stream_headers

      expect(first.reload).to be_paid
      expect(second.reload).to be_paid
      expect(first.date.to_date).to eq(Date.new(2026, 3, 20))
      expect(second.date.to_date).to eq(Date.new(2026, 3, 20))
    end

    it "keeps card-bound exchange dates unchanged when shared settlement installments are paid in bulk" do
      card_transaction = create(
        :card_transaction,
        user:,
        context: user.main_context,
        user_card: create(:user_card, :random, user:, card: create(:card, :random, bank: bank)),
        description: "Bulk mirror source",
        date: Date.new(2026, 3, 10),
        month: 4,
        year: 2026,
        price: -2_000
      )
      card_transaction.category_transactions.destroy_all
      card_transaction.category_transactions.create!(category: user.built_in_category("EXCHANGE"))
      entity_transaction = card_transaction.entity_transactions.first
      entity_transaction.update!(price: -2_000, price_to_be_returned: -2_000, is_payer: true, exchanges_count: 2)
      first_exchange = create(:exchange, entity_transaction:, bound_type: :card_bound, exchange_type: :monetary, number: 1, price: -1_000,
                                         date: Date.new(2026, 4, 10), month: 4, year: 2026)
      second_exchange = create(:exchange, entity_transaction:, bound_type: :card_bound, exchange_type: :monetary, number: 2, price: -1_000,
                                          date: Date.new(2026, 4, 11), month: 4, year: 2026)
      exchange_return = first_exchange.cash_transaction.reload
      exchange_return.cash_installments.delete_all
      exchange_return.cash_installments.create!(number: 1, date: Date.new(2026, 4, 10), month: 4, year: 2026, price: -1_000, starting_price: -1_000,
                                                cash_installments_count: 2)
      exchange_return.cash_installments.create!(number: 2, date: Date.new(2026, 4, 11), month: 4, year: 2026, price: -1_000, starting_price: -1_000,
                                                cash_installments_count: 2)
      exchange_return.update_columns(cash_installments_count: 2, price: -2_000, starting_price: -2_000, date: Date.new(2026, 4, 10), month: 4, year: 2026)
      installments = exchange_return.reload.cash_installments.order(:number)
      paid_at = Time.zone.local(2026, 3, 20, 10, 0, 0)

      post pay_multiple_cash_installments_path, params: {
        ids: installments.pluck(:id),
        cash_installment: {
          date: paid_at.strftime("%Y-%m-%dT%H:%M")
        }
      }, headers: turbo_stream_headers

      expect(response).to have_http_status(:ok)
      expect(first_exchange.reload.date.to_date).to eq(Date.new(2026, 4, 10))
      expect(second_exchange.reload.date.to_date).to eq(Date.new(2026, 4, 11))
      expect(first_exchange.reload.mirrored_paid?).to be(true)
      expect(second_exchange.reload.mirrored_paid?).to be(true)
    end

    it "creates one paid-state message per mirrored shared return transaction even when headers match" do
      sender = create(:user, :random)
      receiver = user
      _origin_card_transaction, sender_shared_return_one, receiver_shared_return_one =
        create_card_origin_shared_return_bundle(sender:, receiver:)
      _origin_cash_transaction, sender_shared_return_two, receiver_shared_return_two =
        create_reimbursement_shared_return_bundle(sender:, receiver:)
      paid_at = Time.zone.local(2026, 3, 27, 12, 0, 0)

      receiver_shared_return_one.update!(description: receiver_shared_return_two.description)
      sender_shared_return_one.update!(description: sender_shared_return_two.description)

      post pay_multiple_cash_installments_path, params: {
        ids: [
          receiver_shared_return_one.cash_installments.find_by!(number: 1).id,
          receiver_shared_return_two.cash_installments.find_by!(number: 1).id
        ],
        cash_installment: {
          date: paid_at.strftime("%Y-%m-%dT%H:%M")
        }
      }, headers: turbo_stream_headers

      assistant_conversation = Conversation.for_users([ sender.id, receiver.id ]).assistant.order(:id).last
      paid_state_messages = assistant_conversation.messages.where(body: "notification:paid_state").order(:id)

      expect(response).to have_http_status(:ok)
      expect(receiver_shared_return_one.cash_installments.find_by!(number: 1).reload).to be_paid
      expect(receiver_shared_return_two.cash_installments.find_by!(number: 1).reload).to be_paid
      expect(sender_shared_return_one.cash_installments.find_by!(number: 1).reload).to be_paid
      expect(sender_shared_return_two.cash_installments.find_by!(number: 1).reload).to be_paid
      expect(paid_state_messages.count).to eq(2)
      expect(paid_state_messages.pluck(:reference_transactable_id)).to match_array(
        [ receiver_shared_return_one.id, receiver_shared_return_two.id ]
      )
    end

    it "pays the counterpart exchange return and not the reimbursement source for the canonical reimbursement chain" do
      sender = create(:user, :random)
      receiver = user
      origin_cash_transaction, sender_shared_return, receiver_shared_return =
        create_reimbursement_shared_return_bundle(sender:, receiver:)
      paid_at = Time.zone.local(2026, 3, 28, 15, 30, 0)

      post pay_multiple_cash_installments_path, params: {
        ids: [ receiver_shared_return.cash_installments.find_by!(number: 1).id ],
        cash_installment: {
          date: paid_at.strftime("%Y-%m-%dT%H:%M")
        }
      }, headers: turbo_stream_headers

      assistant_conversation = Conversation.for_users([ sender.id, receiver.id ]).assistant.order(:id).last
      message = assistant_conversation.messages.where(body: "notification:paid_state").order(:id).last

      expect(response).to have_http_status(:ok)
      expect(receiver_shared_return.cash_installments.find_by!(number: 1).reload).to be_paid
      expect(sender_shared_return.cash_installments.find_by!(number: 1).reload).to be_paid
      expect(origin_cash_transaction.cash_installments.find_by!(number: 1).reload).not_to be_paid
      expect(origin_cash_transaction.reload).not_to be_paid
      expect(message.reference_transactable).to eq(receiver_shared_return)
    end
  end

  describe "[ #partial_pay_multiple ]" do
    it "fully pays all selected installments except the chosen partial installment" do
      first = create(
        :cash_transaction,
        user:,
        user_bank_account:,
        date: installment_date,
        month: 3,
        year: 2026,
        cash_installments: [ build(:cash_installment, number: 1, date: installment_date, month: 3, year: 2026, price: 500, paid: false) ]
      ).cash_installments.first
      second = create(
        :cash_transaction,
        user:,
        user_bank_account:,
        date: installment_date + 1.day,
        month: 3,
        year: 2026,
        cash_installments: [ build(:cash_installment, number: 1, date: installment_date + 1.day, month: 3, year: 2026, price: 700, paid: false) ]
      ).cash_installments.first
      third_transaction = create(
        :cash_transaction,
        user:,
        user_bank_account:,
        date: installment_date + 2.days,
        month: 3,
        year: 2026,
        cash_installments: [ build(:cash_installment, number: 1, date: installment_date + 2.days, month: 3, year: 2026, price: 900, paid: false) ]
      )
      third = third_transaction.cash_installments.first
      paid_at = Time.zone.local(2026, 3, 20, 10, 0, 0)

      expect do
        post partial_pay_multiple_cash_installments_path, params: {
          ids: [ first.id, second.id, third.id ],
          partial_installment_id: third.id,
          cash_installment: {
            date: paid_at.strftime("%Y-%m-%dT%H:%M"),
            price: 1_500
          }
        }, headers: turbo_stream_headers
      end.to change(CashInstallment, :count).by(1)

      third_transaction.reload
      paid_partial = third_transaction.cash_installments.find_by!(number: 1)
      remainder = third_transaction.cash_installments.find_by!(number: 2)

      expect(response).to have_http_status(:ok)
      expect(first.reload).to be_paid
      expect(second.reload).to be_paid
      expect(first.date.to_date).to eq(Date.new(2026, 3, 20))
      expect(second.date.to_date).to eq(Date.new(2026, 3, 20))
      expect(paid_partial.reload).to be_paid
      expect(paid_partial.price).to eq(300)
      expect(paid_partial.date.to_date).to eq(Date.new(2026, 3, 20))
      expect(remainder.price).to eq(600)
      expect(remainder).not_to be_paid
    end

    it "rejects amounts outside the allowed partial-pay range" do
      first = create(
        :cash_transaction,
        user:,
        user_bank_account:,
        date: installment_date,
        month: 3,
        year: 2026,
        cash_installments: [ build(:cash_installment, number: 1, date: installment_date, month: 3, year: 2026, price: 500, paid: false) ]
      ).cash_installments.first
      second = create(
        :cash_transaction,
        user:,
        user_bank_account:,
        date: installment_date + 1.day,
        month: 3,
        year: 2026,
        cash_installments: [ build(:cash_installment, number: 1, date: installment_date + 1.day, month: 3, year: 2026, price: 700, paid: false) ]
      ).cash_installments.first
      third = create(
        :cash_transaction,
        user:,
        user_bank_account:,
        date: installment_date + 2.days,
        month: 3,
        year: 2026,
        cash_installments: [ build(:cash_installment, number: 1, date: installment_date + 2.days, month: 3, year: 2026, price: 900, paid: false) ]
      ).cash_installments.first

      expect do
        post partial_pay_multiple_cash_installments_path, params: {
          ids: [ first.id, second.id, third.id ],
          partial_installment_id: third.id,
          cash_installment: {
            date: Time.zone.local(2026, 3, 20, 10, 0, 0).strftime("%Y-%m-%dT%H:%M"),
            price: 1_000
          }
        }, headers: turbo_stream_headers
      end.not_to change(CashInstallment, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include(I18n.t("bulk_actions.partial_pay.invalid_amount"))
      expect(first.reload).not_to be_paid
      expect(second.reload).not_to be_paid
      expect(third.reload).not_to be_paid
    end

    it "rejects partial-installment selections that cannot remain partially unpaid" do
      first = create(
        :cash_transaction,
        user:,
        user_bank_account:,
        date: installment_date,
        month: 3,
        year: 2026,
        cash_installments: [ build(:cash_installment, number: 1, date: installment_date, month: 3, year: 2026, price: 500, paid: false) ]
      ).cash_installments.first
      second = create(
        :cash_transaction,
        user:,
        user_bank_account:,
        date: installment_date + 1.day,
        month: 3,
        year: 2026,
        cash_installments: [ build(:cash_installment, number: 1, date: installment_date + 1.day, month: 3, year: 2026, price: 700, paid: false) ]
      ).cash_installments.first
      third = create(
        :cash_transaction,
        user:,
        user_bank_account:,
        date: installment_date + 2.days,
        month: 3,
        year: 2026,
        cash_installments: [ build(:cash_installment, number: 1, date: installment_date + 2.days, month: 3, year: 2026, price: 900, paid: false) ]
      ).cash_installments.first

      expect do
        post partial_pay_multiple_cash_installments_path, params: {
          ids: [ first.id, second.id, third.id ],
          partial_installment_id: first.id,
          cash_installment: {
            date: Time.zone.local(2026, 3, 20, 10, 0, 0).strftime("%Y-%m-%dT%H:%M"),
            price: 1_500
          }
        }, headers: turbo_stream_headers
      end.not_to change(CashInstallment, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include(I18n.t("bulk_actions.partial_pay.invalid_selection"))
      expect(first.reload).not_to be_paid
      expect(second.reload).not_to be_paid
      expect(third.reload).not_to be_paid
    end
  end

  describe "[ #transfer_multiple ]" do
    it "moves all selected installments to the chosen reference month" do
      first = create(
        :cash_transaction,
        user:,
        user_bank_account:,
        date: installment_date,
        month: 3,
        year: 2026,
        cash_installments: [ build(:cash_installment, number: 1, date: installment_date, month: 3, year: 2026, price: 500, paid: false) ]
      ).cash_installments.first
      second = create(
        :cash_transaction,
        user:,
        user_bank_account:,
        date: installment_date + 1.day,
        month: 3,
        year: 2026,
        cash_installments: [ build(:cash_installment, number: 1, date: installment_date + 1.day, month: 3, year: 2026, price: 700, paid: false) ]
      ).cash_installments.first

      post transfer_multiple_cash_installments_path, params: {
        ids: [ first.id, second.id ],
        reference_date: "2026-05",
        cash_installment: {
          date: Time.zone.local(2026, 5, 2, 9, 0, 0).strftime("%Y-%m-%dT%H:%M")
        }
      }, headers: turbo_stream_headers

      expect(first.reload.month).to eq(5)
      expect(first.year).to eq(2026)
      expect(second.reload.month).to eq(5)
      expect(second.year).to eq(2026)
      expect(first.date.to_date).to eq(Date.new(2026, 5, 2))
      expect(second.date.to_date).to eq(Date.new(2026, 5, 2))
      expect(first).not_to be_paid
      expect(second).not_to be_paid
    end

    it "keeps card-bound exchange dates unchanged when shared settlement installments are transferred" do
      card_transaction = create(
        :card_transaction,
        user:,
        context: user.main_context,
        user_card: create(:user_card, :random, user:, card: create(:card, :random, bank: bank)),
        description: "Transfer mirror source",
        date: Date.new(2026, 3, 10),
        month: 4,
        year: 2026,
        price: -2_000
      )
      card_transaction.category_transactions.destroy_all
      card_transaction.category_transactions.create!(category: user.built_in_category("EXCHANGE"))
      entity_transaction = card_transaction.entity_transactions.first
      entity_transaction.update!(price: -2_000, price_to_be_returned: -2_000, is_payer: true, exchanges_count: 2)
      first_exchange = create(:exchange, entity_transaction:, bound_type: :card_bound, exchange_type: :monetary, number: 1, price: -1_000,
                                         date: Date.new(2026, 4, 10), month: 4, year: 2026)
      second_exchange = create(:exchange, entity_transaction:, bound_type: :card_bound, exchange_type: :monetary, number: 2, price: -1_000,
                                          date: Date.new(2026, 5, 10), month: 5, year: 2026)
      installments = first_exchange.cash_transaction.reload.cash_installments.order(:number)
      transferred_at = Time.zone.local(2026, 5, 2, 9, 0, 0)

      post transfer_multiple_cash_installments_path, params: {
        ids: installments.pluck(:id),
        reference_date: "2026-05",
        cash_installment: {
          date: transferred_at.strftime("%Y-%m-%dT%H:%M")
        }
      }, headers: turbo_stream_headers

      expect(response).to have_http_status(:ok)
      expect(first_exchange.reload.date.to_date).to eq(Date.new(2026, 4, 10))
      expect(first_exchange.month).to eq(4)
      expect(second_exchange.reload.date.to_date).to eq(Date.new(2026, 5, 10))
      expect(second_exchange.month).to eq(5)
      expect(first_exchange.reload.mirrored_paid?).to be(false)
      expect(second_exchange.reload.mirrored_paid?).to be(false)
    end
  end

  describe "[ context isolation ]" do
    it "keeps pay changes inside the derived context" do
      main_cash_transaction = create(
        :cash_transaction,
        user:,
        context: user.main_context,
        user_bank_account:,
        description: "Main installment isolation",
        date: installment_date,
        month: 3,
        year: 2026,
        price: 1000,
        cash_installments: [
          build(:cash_installment, number: 1, date: installment_date, month: 3, year: 2026, price: 1000, paid: false)
        ]
      )
      main_installment = main_cash_transaction.cash_installments.first

      derived_context = Logic::ContextCloneService.new(
        source_context: user.main_context,
        name: "Cash Installment Isolation"
      ).call
      derived_installment = derived_context.cash_installments.find_by!(
        cash_transaction: derived_context.cash_transactions.find_by!(description: main_cash_transaction.description),
        number: 1
      )

      switch_to_context!(derived_context)

      patch pay_cash_installment_path(derived_installment), params: {
        cash_installment: {
          date: Time.zone.local(2026, 3, 12, 12, 0, 0).strftime("%Y-%m-%dT%H:%M"),
          price: 600
        }
      }, headers: turbo_stream_headers

      expect(derived_installment.reload).to be_paid
      expect(derived_installment.price).to eq(600)
      expect(main_installment.reload).not_to be_paid
      expect(main_installment.price).to eq(1000)
    end

    it "keeps pay_multiple changes inside the derived context" do
      first_main = create(
        :cash_transaction,
        user:,
        context: user.main_context,
        user_bank_account:,
        description: "Main bulk installment one",
        date: installment_date,
        month: 3,
        year: 2026,
        cash_installments: [ build(:cash_installment, number: 1, date: installment_date, month: 3, year: 2026, price: 500, paid: false) ]
      ).cash_installments.first
      second_main = create(
        :cash_transaction,
        user:,
        context: user.main_context,
        user_bank_account:,
        description: "Main bulk installment two",
        date: installment_date + 1.day,
        month: 3,
        year: 2026,
        cash_installments: [ build(:cash_installment, number: 1, date: installment_date + 1.day, month: 3, year: 2026, price: 700, paid: false) ]
      ).cash_installments.first

      derived_context = Logic::ContextCloneService.new(
        source_context: user.main_context,
        name: "Cash Installment Bulk Isolation"
      ).call
      first_derived = derived_context.cash_transactions.find_by!(description: "Main bulk installment one").cash_installments.first
      second_derived = derived_context.cash_transactions.find_by!(description: "Main bulk installment two").cash_installments.first

      switch_to_context!(derived_context)

      post pay_multiple_cash_installments_path, params: {
        ids: [ first_derived.id, second_derived.id ],
        cash_installment: {
          date: Time.zone.local(2026, 3, 20, 10, 0, 0).strftime("%Y-%m-%dT%H:%M")
        }
      }, headers: turbo_stream_headers

      expect(first_derived.reload).to be_paid
      expect(second_derived.reload).to be_paid
      expect(first_main.reload).not_to be_paid
      expect(second_main.reload).not_to be_paid
    end

    it "keeps transfer_multiple changes inside the derived context" do
      first_main = create(
        :cash_transaction,
        user:,
        context: user.main_context,
        user_bank_account:,
        description: "Main transfer installment one",
        date: installment_date,
        month: 3,
        year: 2026,
        cash_installments: [ build(:cash_installment, number: 1, date: installment_date, month: 3, year: 2026, price: 500, paid: false) ]
      ).cash_installments.first
      second_main = create(
        :cash_transaction,
        user:,
        context: user.main_context,
        user_bank_account:,
        description: "Main transfer installment two",
        date: installment_date + 1.day,
        month: 3,
        year: 2026,
        cash_installments: [ build(:cash_installment, number: 1, date: installment_date + 1.day, month: 3, year: 2026, price: 700, paid: false) ]
      ).cash_installments.first

      derived_context = Logic::ContextCloneService.new(
        source_context: user.main_context,
        name: "Cash Installment Transfer Isolation"
      ).call
      first_derived = derived_context.cash_transactions.find_by!(description: "Main transfer installment one").cash_installments.first
      second_derived = derived_context.cash_transactions.find_by!(description: "Main transfer installment two").cash_installments.first

      switch_to_context!(derived_context)

      post transfer_multiple_cash_installments_path, params: {
        ids: [ first_derived.id, second_derived.id ],
        reference_date: "2026-05",
        cash_installment: {
          date: Time.zone.local(2026, 5, 2, 9, 0, 0).strftime("%Y-%m-%dT%H:%M")
        }
      }, headers: turbo_stream_headers

      expect(first_derived.reload.month).to eq(5)
      expect(second_derived.reload.month).to eq(5)
      expect(first_main.reload.month).to eq(3)
      expect(second_main.reload.month).to eq(3)
    end

    it "keeps partial_pay_multiple changes inside the derived context" do
      first_main = create(
        :cash_transaction,
        user:,
        context: user.main_context,
        user_bank_account:,
        description: "Main partial installment one",
        date: installment_date,
        month: 3,
        year: 2026,
        cash_installments: [ build(:cash_installment, number: 1, date: installment_date, month: 3, year: 2026, price: 500, paid: false) ]
      ).cash_installments.first
      second_main_transaction = create(
        :cash_transaction,
        user:,
        context: user.main_context,
        user_bank_account:,
        description: "Main partial installment two",
        date: installment_date + 1.day,
        month: 3,
        year: 2026,
        cash_installments: [ build(:cash_installment, number: 1, date: installment_date + 1.day, month: 3, year: 2026, price: 700, paid: false) ]
      )
      second_main = second_main_transaction.cash_installments.first

      derived_context = Logic::ContextCloneService.new(
        source_context: user.main_context,
        name: "Cash Installment Partial Isolation"
      ).call
      first_derived = derived_context.cash_transactions.find_by!(description: "Main partial installment one").cash_installments.first
      second_derived_transaction = derived_context.cash_transactions.find_by!(description: "Main partial installment two")
      second_derived = second_derived_transaction.cash_installments.first

      switch_to_context!(derived_context)

      expect do
        post partial_pay_multiple_cash_installments_path, params: {
          ids: [ first_derived.id, second_derived.id ],
          partial_installment_id: second_derived.id,
          cash_installment: {
            date: Time.zone.local(2026, 3, 20, 10, 0, 0).strftime("%Y-%m-%dT%H:%M"),
            price: 800
          }
        }, headers: turbo_stream_headers
      end.to change { second_derived_transaction.reload.cash_installments.count }.by(1)

      expect(first_derived.reload).to be_paid
      expect(second_derived.reload).to be_paid
      expect(second_derived.price).to eq(300)
      expect(first_main.reload).not_to be_paid
      expect(second_main.reload).not_to be_paid
    end

    it "does not allow paying a main-context installment while switched to the derived context" do
      main_cash_transaction = create(
        :cash_transaction,
        user:,
        context: user.main_context,
        user_bank_account:,
        description: "Main inaccessible installment",
        date: installment_date,
        month: 3,
        year: 2026,
        price: 1000,
        cash_installments: [
          build(:cash_installment, number: 1, date: installment_date, month: 3, year: 2026, price: 1000, paid: false)
        ]
      )
      main_installment = main_cash_transaction.cash_installments.first

      derived_context = Logic::ContextCloneService.new(
        source_context: user.main_context,
        name: "Cash Installment Access Isolation"
      ).call

      switch_to_context!(derived_context)

      patch pay_cash_installment_path(main_installment), params: {
        cash_installment: {
          date: Time.zone.local(2026, 3, 12, 12, 0, 0).strftime("%Y-%m-%dT%H:%M"),
          price: 600
        }
      }, headers: turbo_stream_headers

      expect(response).to have_http_status(:not_found)
    end
  end
end
