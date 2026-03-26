# frozen_string_literal: true

require "rails_helper"

RSpec.describe "CashTransactions", type: :request do
  let(:user) { create(:user, :random) }
  let(:bank) { create(:bank, :random) }
  let(:user_bank_account) { create(:user_bank_account, :random, user:, bank:) }
  let(:category) { create(:category, :random, user:) }
  let(:entity) { create(:entity, :random, user:) }
  let(:subscription) { create(:subscription, user:) }

  let(:cash_transaction) do
    Params::CashTransactions.new(
      cash_transaction: {
        description: "Salary payment",
        price: 20_000,
        date: Time.zone.today,
        month: Time.zone.today.month,
        year: Time.zone.today.year,
        user_id: user.id,
        user_bank_account_id: user_bank_account.id,
        subscription_id: subscription.id
      },
      cash_installments: { count: 1 },
      category_transactions: [ { category_id: category.id } ],
      entity_transactions: [ {
        entity_id: entity.id,
        price: 0,
        price_to_be_returned: 0,
        exchanges_attributes: []
      } ]
    )
  end

  before { sign_in user }

  def switch_to_context!(context)
    patch switch_context_path(context)
    expect(response).to redirect_to(root_path)
  end

  def create_cash_transaction_with_paid_history(description: "Locked cash transaction")
    transaction = create(
      :cash_transaction,
      user:,
      context: user.main_context,
      user_bank_account: user_bank_account,
      description:,
      price: 3_000,
      date: Date.new(2026, 3, 10),
      month: 3,
      year: 2026
    )
    transaction.cash_installments.destroy_all
    transaction.cash_installments.create!(number: 1, price: 1_000, date: Date.new(2026, 3, 10), month: 3, year: 2026, paid: true)
    transaction.cash_installments.create!(number: 2, price: 1_000, date: Date.new(2026, 4, 10), month: 4, year: 2026, paid: false)
    transaction.cash_installments.create!(number: 3, price: 1_000, date: Date.new(2026, 5, 10), month: 5, year: 2026, paid: false)
    transaction.update_column(:cash_installments_count, 3)
    transaction.categories = [ create(:category, user:, category_name: "FOOD") ]
    transaction.save!
    transaction.reload
  end

  def create_shared_return_pair(sender:, receiver:, sender_context: sender.main_context, receiver_context: receiver.main_context) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
    create(:entity, user: sender, entity_name: receiver.first_name.upcase, entity_user: receiver)
    receiver_counterpart = create(:entity, user: receiver, entity_name: sender.first_name.upcase, entity_user: sender)
    sender_bank_account = create(:user_bank_account, user: sender, bank: create(:bank, :random))
    receiver_bank_account = create(:user_bank_account, user: receiver, bank: create(:bank, :random))

    sender_transaction = create(
      :cash_transaction,
      user: sender,
      context: sender_context,
      user_bank_account: sender_bank_account,
      description: "Shared return",
      date: Date.new(2026, 3, 24),
      month: 3,
      year: 2026,
      price: -7_500,
      category_transactions_attributes: [
        { category_id: sender.built_in_category("EXCHANGE RETURN").id }
      ],
      entity_transactions_attributes: [
        { entity_id: sender.entities.that_are_users.find_by(entity_user: receiver).id, is_payer: false, price: 0, price_to_be_returned: 0 }
      ],
      cash_installments_attributes: [
        { number: 1, date: Date.new(2026, 3, 24), month: 3, year: 2026, price: -7_500, paid: true }
      ]
    )
    sender_transaction.cash_installments.destroy_all
    sender_transaction.cash_installments.create!(number: 1, date: Date.new(2026, 3, 24), month: 3, year: 2026, price: -7_500, paid: true)
    sender_transaction.update_column(:cash_installments_count, 1)

    receiver_transaction = create(
      :cash_transaction,
      user: receiver,
      context: receiver_context,
      user_bank_account: receiver_bank_account,
      reference_transactable: sender_transaction,
      description: "Shared return",
      date: Date.new(2026, 3, 24),
      month: 3,
      year: 2026,
      price: -7_500,
      category_transactions_attributes: [
        { category_id: receiver.built_in_category("BORROW RETURN").id }
      ],
      entity_transactions_attributes: [
        { entity_id: receiver_counterpart.id, is_payer: false, price: 0, price_to_be_returned: 0 }
      ],
      cash_installments_attributes: [
        { number: 1, date: Date.new(2026, 3, 24), month: 3, year: 2026, price: -7_500, paid: true }
      ]
    )
    receiver_transaction.cash_installments.destroy_all
    receiver_transaction.cash_installments.create!(number: 1, date: Date.new(2026, 3, 24), month: 3, year: 2026, price: -7_500, paid: true)
    receiver_transaction.update_column(:cash_installments_count, 1)

    [ sender_transaction, receiver_transaction ]
  end

  describe "[ #create ]" do
    it "creates a cash transaction with installments, categories, and entities" do
      expect { post cash_transactions_path, params: cash_transaction.params, headers: turbo_stream_headers }.to change(CashTransaction, :count).by(1)

      created_cash_transaction = CashTransaction.last

      expect(created_cash_transaction.description).to eq("Salary payment")
      expect(created_cash_transaction.subscription).to eq(subscription)
      expect(created_cash_transaction.cash_installments.count).to eq(1)
      expect(created_cash_transaction.categories).to include(category)
      expect(created_cash_transaction.entities).to include(entity)
      expect(subscription.reload.price).to eq(20_000)
    end

    it "passes reimbursement intent through to exchange notifications with the correct payload shape" do
      other_user = create(:user, :random)
      create(:entity, user:, entity_name: "OTHER USER", entity_user: other_user)
      other_user_entity = create(:entity, user: other_user, entity_name: "ME", entity_user: user)
      Conversation.create!.tap do |record|
        record.conversation_participants.create!(user:)
        record.conversation_participants.create!(user: other_user)
      end

      cash_transaction.category_transactions = [ { category_id: user.built_in_category("EXCHANGE").id } ]
      cash_transaction.entity_transactions = [ {
        entity_id: user.entities.that_are_users.find_by(entity_user: other_user).id,
        price: -20_000,
        price_to_be_returned: -20_000,
        exchanges_attributes: [
          { price: -20_000, date: Time.zone.today, month: Time.zone.today.month, year: Time.zone.today.year }
        ]
      } ]
      cash_transaction.friend_notification_intent = "reimbursement"

      post cash_transactions_path, params: cash_transaction.params, headers: turbo_stream_headers

      headers = JSON.parse(Message.last.headers)

      expect(headers).to include("version" => "message_notification_v2")
      expect(headers.fetch("replay")).to include(
        "version" => "cash_exchange_v2",
        "intent" => "reimbursement",
        "category_ids" => other_user.built_in_category("BORROW RETURN").id,
        "entity_ids" => other_user_entity.id
      )
      expect(headers.fetch("replay").fetch("cash_installments_attributes")).to contain_exactly(
        a_hash_including("price" => 20_000)
      )
      expect(headers.fetch("replay").fetch("entity_transactions_attributes")).to contain_exactly(
        a_hash_including(
          "is_payer" => false,
          "price" => 0,
          "price_to_be_returned" => 0,
          "entity_id" => other_user_entity.id,
          "exchanges_count" => 0
        )
      )
    end

    it "defaults pure exchange notifications to loan intent" do
      other_user = create(:user, :random)
      create(:entity, user:, entity_name: "OTHER USER", entity_user: other_user)
      other_user_entity = create(:entity, user: other_user, entity_name: "ME", entity_user: user)
      Conversation.create!.tap do |record|
        record.conversation_participants.create!(user:)
        record.conversation_participants.create!(user: other_user)
      end

      cash_transaction.category_transactions = [ { category_id: user.built_in_category("EXCHANGE").id } ]
      cash_transaction.entity_transactions = [ {
        entity_id: user.entities.that_are_users.find_by(entity_user: other_user).id,
        price: -20_000,
        price_to_be_returned: -20_000,
        exchanges_attributes: [
          { price: -20_000, date: Time.zone.today, month: Time.zone.today.month, year: Time.zone.today.year }
        ]
      } ]

      post cash_transactions_path, params: cash_transaction.params, headers: turbo_stream_headers

      headers = JSON.parse(Message.last.headers)

      expect(headers).to include("version" => "message_notification_v2")
      expect(headers.fetch("replay")).to include(
        "version" => "cash_exchange_v2",
        "intent" => "loan",
        "category_ids" => other_user.built_in_category("EXCHANGE").id
      )
      expect(headers.fetch("replay").fetch("entity_transactions_attributes")).to contain_exactly(
        a_hash_including(
          "is_payer" => true,
          "price" => 20_000,
          "price_to_be_returned" => 20_000,
          "entity_id" => other_user_entity.id,
          "exchanges_count" => 1
        )
      )
    end

    it "marks the source message as applied when creating from a message" do
      other_user = create(:user, :random)
      conversation = Conversation.create!.tap do |record|
        record.conversation_participants.create!(user:)
        record.conversation_participants.create!(user: other_user)
      end
      source_message = conversation.messages.create!(
        user: other_user,
        body: "notification:create",
        headers: {
          version: "message_notification_v2",
          event: {
            action: "create",
            receiver_first_name: user.first_name,
            transaction_type: "CashTransaction",
            details: { description: "Salary payment" }
          },
          replay: { id: 999, type: "CashTransaction" }
        }.to_json
      )

      post cash_transactions_path, params: cash_transaction.params.deep_merge(
        cash_transaction: { source_message_id: source_message.id }
      ), headers: turbo_stream_headers

      expect(source_message.reload.applied_at).to be_present
    end

    it "refuses to save a stale actionable form into the newly selected context" do
      sender = create(:user, :random)
      receiver = create(:user, :random)
      receiver_bank_account = create(:user_bank_account, :random, user: receiver, bank: create(:bank, :random))
      create(:entity, user: sender, entity_name: "RECEIVER", entity_user: receiver)
      receiver_counterpart = create(:entity, user: receiver, entity_name: "SENDER", entity_user: sender)
      derived_context = Logic::ContextCloneService.new(
        source_context: receiver.main_context,
        name: "Optimistic",
        scenario_key: "scenario-optimistic"
      ).call

      conversation = Conversation.find_or_create_assistant_between!(sender, receiver, scenario_key: derived_context.scenario_key)
      source_message = conversation.messages.create!(
        user: sender,
        body: "notification:create",
        headers: {
          version: "message_notification_v2",
          event: {
            action: "create",
            receiver_first_name: receiver.first_name,
            transaction_type: "CashTransaction",
            details: { description: "Shared reimbursement" }
          },
          replay: {
            id: 999,
            type: "CashTransaction",
            description: "Shared reimbursement",
            price: 20_000,
            date: Date.new(2026, 3, 24).iso8601,
            month: 3,
            year: 2026,
            category_ids: receiver.built_in_category("BORROW RETURN").id,
            entity_ids: receiver_counterpart.id,
            cash_installments_attributes: [
              { number: 1, date: Date.new(2026, 3, 24).iso8601, month: 3, year: 2026, price: 20_000 }
            ],
            entity_transactions_attributes: [
              {
                entity_id: receiver_counterpart.id,
                is_payer: false,
                price: 0,
                price_to_be_returned: 0,
                exchanges_count: 0,
                exchanges_attributes: []
              }
            ]
          }
        }.to_json
      )

      sign_out user
      sign_in receiver

      switch_to_context!(derived_context)
      get new_cash_transaction_path(cash_transaction: { source_message_id: source_message.id })
      switch_to_context!(receiver.main_context)

      expect do
        post cash_transactions_path, params: {
          cash_transaction: {
            context_id: derived_context.id,
            description: "Shared reimbursement",
            price: 20_000,
            date: Date.new(2026, 3, 24),
            month: 3,
            year: 2026,
            user_id: receiver.id,
            user_bank_account_id: receiver_bank_account.id,
            reference_transactable_type: "CashTransaction",
            reference_transactable_id: 999,
            friend_notification_intent: "reimbursement",
            source_message_id: source_message.id,
            category_transactions_attributes: [
              { category_id: receiver.built_in_category("BORROW RETURN").id }
            ],
            entity_transactions_attributes: [
              {
                entity_id: receiver_counterpart.id,
                is_payer: false,
                price: 0,
                price_to_be_returned: 0,
                exchanges_count: 0,
                exchanges_attributes: []
              }
            ],
            cash_installments_attributes: [
              {
                number: 1,
                date: Date.new(2026, 3, 24),
                month: 3,
                year: 2026,
                price: 20_000
              }
            ]
          }
        }, headers: turbo_stream_headers
      end.not_to change(CashTransaction, :count)

      expect(response).to redirect_to(cash_transactions_path)
      expect(flash[:alert]).to eq(I18n.t("contexts.switch.stale_transaction_form"))
      expect(source_message.reload.applied_at).to be_nil
    end

    it "keeps reimbursement source linkage so later update and destroy notifications resolve the receiver transaction" do
      sender = create(:user, :random)
      receiver = create(:user, :random)
      sender_bank_account = create(:user_bank_account, :random, user: sender, bank: create(:bank, :random))
      receiver_bank_account = create(:user_bank_account, :random, user: receiver, bank: create(:bank, :random))
      create(:entity, user: sender, entity_name: "RECEIVER", entity_user: receiver)
      receiver_counterpart = create(:entity, user: receiver, entity_name: "SENDER", entity_user: sender)

      sender_transaction = create(
        :cash_transaction,
        user: sender,
        context: sender.main_context,
        user_bank_account: sender_bank_account,
        description: "Shared reimbursement",
        price: -20_000,
        date: Date.new(2026, 3, 24),
        month: 3,
        year: 2026,
        category_transactions_attributes: [
          { category_id: sender.built_in_category("EXCHANGE").id }
        ],
        cash_installments_attributes: [
          { number: 1, price: -20_000, date: Date.new(2026, 3, 24), month: 3, year: 2026 }
        ],
        entity_transactions_attributes: [
          {
            entity_id: sender.entities.that_are_users.find_by(entity_user: receiver).id,
            is_payer: true,
            price: -20_000,
            price_to_be_returned: -20_000,
            exchanges_count: 1,
            exchanges_attributes: [
              { number: 1, price: -20_000, date: Date.new(2026, 3, 24), month: 3, year: 2026 }
            ]
          }
        ],
        friend_notification_intent: "reimbursement"
      )

      conversation = Conversation.find_or_create_assistant_between!(sender, receiver)
      create_message = conversation.messages.order(:id).last

      sign_out user
      sign_in receiver

      get new_cash_transaction_path(cash_transaction: { source_message_id: create_message.id })

      document = Nokogiri::HTML.parse(response.body)

      expect(document.at_css('input[name="cash_transaction[reference_transactable_type]"]')["value"]).to eq("CashTransaction")
      expect(document.at_css('input[name="cash_transaction[reference_transactable_id]"]')["value"]).to eq(sender_transaction.id.to_s)
      expect(document.at_css('input[name="cash_transaction[friend_notification_intent]"]')["value"]).to eq("reimbursement")

      post cash_transactions_path, params: {
        cash_transaction: {
          description: "Shared reimbursement",
          price: 20_000,
          date: Date.new(2026, 3, 24),
          month: 3,
          year: 2026,
          user_id: receiver.id,
          user_bank_account_id: receiver_bank_account.id,
          reference_transactable_type: "CashTransaction",
          reference_transactable_id: sender_transaction.id,
          friend_notification_intent: "reimbursement",
          source_message_id: create_message.id,
          category_transactions_attributes: [
            { category_id: receiver.built_in_category("BORROW RETURN").id }
          ],
          entity_transactions_attributes: [
            {
              entity_id: receiver_counterpart.id,
              is_payer: false,
              price: 0,
              price_to_be_returned: 0,
              exchanges_count: 0,
              exchanges_attributes: []
            }
          ],
          cash_installments_attributes: [
            {
              number: 1,
              date: Date.new(2026, 3, 24),
              month: 3,
              year: 2026,
              price: 20_000
            }
          ]
        }
      }, headers: turbo_stream_headers

      receiver_transaction = receiver.main_context.cash_transactions.order(:id).last

      expect(receiver_transaction.reference_transactable).to eq(sender_transaction)

      sender_transaction.update!(description: "Shared reimbursement updated")
      update_message = conversation.messages.where(body: "notification:update").order(:id).last

      get conversation_path(conversation, message_filter: "all")

      expect(response.body).to include(
        edit_cash_transaction_path(
          id: receiver_transaction,
          cash_transaction: { source_message_id: update_message.id },
          format: :turbo_stream
        )
      )
      expect(response.body).not_to include(
        new_cash_transaction_path(cash_transaction: { source_message_id: update_message.id }, format: :turbo_stream)
      )

      sender_transaction.destroy
      destroy_message = conversation.messages.where(body: "notification:destroy").order(:id).last

      get conversation_path(conversation, message_filter: "all")

      expect(response.body).to include(
        cash_transaction_path(id: receiver_transaction, format: :turbo_stream, message_id: destroy_message.id)
      )
      expect(receiver_transaction.reload).to be_present
    end
  end

  describe "[ #update ]" do
    before do
      cash_transaction.date = 1.month.from_now.to_date
      cash_transaction.month = cash_transaction.date.month
      cash_transaction.year = cash_transaction.date.year
      post cash_transactions_path, params: cash_transaction.params, headers: turbo_stream_headers
      @existing_cash_transaction = CashTransaction.last
    end

    it "updates the record and its installment price" do
      cash_transaction.use_base(@existing_cash_transaction, cash_transaction_options: { price: 35_000, description: "Updated salary" })
      cash_transaction.cash_installments.first[:price] = 35_000

      put cash_transaction_path(@existing_cash_transaction), params: cash_transaction.params, headers: turbo_stream_headers

      @existing_cash_transaction.reload

      expect(@existing_cash_transaction.description).to eq("Updated salary")
      expect(@existing_cash_transaction.price).to eq(35_000)
      expect(@existing_cash_transaction.cash_installments.first.price).to eq(35_000)
      expect(subscription.reload.price).to eq(35_000)
    end

    it "updates the linked subscription" do
      other_subscription = create(:subscription, user:)
      cash_transaction.use_base(@existing_cash_transaction, cash_transaction_options: { subscription_id: other_subscription.id })

      put cash_transaction_path(@existing_cash_transaction), params: cash_transaction.params, headers: turbo_stream_headers

      expect(@existing_cash_transaction.reload.subscription).to eq(other_subscription)
      expect(subscription.reload.price).to eq(0)
      expect(other_subscription.reload.price).to eq(20_000)
    end

    it "treats a no-op update as successful" do
      cash_transaction.use_base(@existing_cash_transaction)
      original_description = @existing_cash_transaction.description

      put cash_transaction_path(@existing_cash_transaction), params: cash_transaction.params, headers: turbo_stream_headers

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t("notification.updateda", model: CashTransaction.model_name.human))
      expect(response.body).not_to include(I18n.t("notification.not_updateda", model: CashTransaction.model_name.human))
      expect(@existing_cash_transaction.reload.description).to eq(original_description)
    end

    it "marks the source message as applied when updating from a message" do
      other_user = create(:user, :random)
      conversation = Conversation.create!.tap do |record|
        record.conversation_participants.create!(user:)
        record.conversation_participants.create!(user: other_user)
      end
      source_message = conversation.messages.create!(
        user: other_user,
        body: "notification:update",
        headers: {
          version: "message_notification_v2",
          event: {
            action: "update",
            receiver_first_name: user.first_name,
            transaction_type: "CashTransaction",
            details: { description: "Salary payment" }
          },
          replay: { id: @existing_cash_transaction.id, type: "CashTransaction" }
        }.to_json
      )
      cash_transaction.use_base(@existing_cash_transaction, cash_transaction_options: { description: "Adjusted salary" })

      put cash_transaction_path(@existing_cash_transaction), params: cash_transaction.params.deep_merge(
        cash_transaction: { source_message_id: source_message.id }
      ), headers: turbo_stream_headers

      expect(source_message.reload.applied_at).to be_present
    end

    it "does not mark the source message as applied when a paid-history rewrite is blocked" do
      locked_transaction = create_cash_transaction_with_paid_history(description: "Locked replay update")
      other_user = create(:user, :random)
      conversation = Conversation.create!.tap do |record|
        record.conversation_participants.create!(user:)
        record.conversation_participants.create!(user: other_user)
      end
      source_message = conversation.messages.create!(
        user: other_user,
        body: "notification:update",
        headers: {
          version: "message_notification_v2",
          event: {
            action: "update",
            receiver_first_name: user.first_name,
            transaction_type: "CashTransaction",
            details: { description: "Locked replay update" }
          },
          replay: {
            id: locked_transaction.id,
            type: "CashTransaction",
            description: locked_transaction.description,
            price: locked_transaction.price,
            date: locked_transaction.date,
            month: locked_transaction.month,
            year: locked_transaction.year
          }
        }.to_json
      )
      second_installment = locked_transaction.cash_installments.find_by!(number: 2)

      put cash_transaction_path(locked_transaction), params: {
        cash_transaction: {
          description: locked_transaction.description,
          price: locked_transaction.price,
          date: locked_transaction.date,
          month: locked_transaction.month,
          year: locked_transaction.year,
          user_id: user.id,
          user_bank_account_id: user_bank_account.id,
          source_message_id: source_message.id,
          category_transactions_attributes: locked_transaction.category_transactions.map { |ct| { id: ct.id, category_id: ct.category_id } },
          entity_transactions_attributes: [],
          cash_installments_attributes: [
            {
              id: second_installment.id,
              number: second_installment.number,
              date: Date.new(2026, 3, 10),
              month: 3,
              year: 2026,
              price: second_installment.price
            }
          ]
        }
      }, headers: turbo_stream_headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(source_message.reload.applied_at).to be_nil
    end

    it "keeps the source message id in the edit form opened from a message" do
      other_user = create(:user, :random)
      conversation = Conversation.create!.tap do |record|
        record.conversation_participants.create!(user:)
        record.conversation_participants.create!(user: other_user)
      end
      source_message = conversation.messages.create!(
        user: other_user,
        body: "notification:update",
        headers: {
          version: "message_notification_v2",
          event: {
            action: "update",
            receiver_first_name: user.first_name,
            transaction_type: "CashTransaction",
            details: { description: "Salary payment" }
          },
          replay: {
            id: @existing_cash_transaction.id,
            type: "CashTransaction",
            reference_transactable_type: "CashTransaction",
            reference_transactable_id: @existing_cash_transaction.id,
            description: "Salary payment",
            price: @existing_cash_transaction.price,
            date: @existing_cash_transaction.date,
            month: @existing_cash_transaction.month,
            year: @existing_cash_transaction.year,
            category_ids: @existing_cash_transaction.categories.ids,
            entity_ids: @existing_cash_transaction.entities.ids,
            cash_installments_attributes: @existing_cash_transaction.cash_installments.map do |installment|
              {
                number: installment.number,
                price: installment.price,
                date: installment.date,
                month: installment.month,
                year: installment.year
              }
            end,
            entity_transactions_attributes: []
          }
        }.to_json
      )

      get edit_cash_transaction_path(@existing_cash_transaction, cash_transaction: { source_message_id: source_message.id })

      expect(response.body).to include(%[value="#{source_message.id}"])
      expect(response.body).to include(%(name="cash_transaction[source_message_id]"))
      expect(response.body).to include(%(name="cash_transaction[reference_transactable_type]"))
      expect(response.body).to include(%(name="cash_transaction[reference_transactable_id]"))
      expect(response.body).to include(%[value="#{@existing_cash_transaction.entities.first.id}"])
    end

    it "returns unprocessable_entity when a paid-history rewrite is blocked" do
      locked_transaction = create_cash_transaction_with_paid_history
      second_installment = locked_transaction.cash_installments.find_by!(number: 2)

      put cash_transaction_path(locked_transaction), params: {
        cash_transaction: {
          description: locked_transaction.description,
          price: locked_transaction.price,
          date: locked_transaction.date,
          month: locked_transaction.month,
          year: locked_transaction.year,
          user_id: user.id,
          user_bank_account_id: user_bank_account.id,
          category_transactions_attributes: locked_transaction.category_transactions.map { |ct| { id: ct.id, category_id: ct.category_id } },
          entity_transactions_attributes: [],
          cash_installments_attributes: [
            {
              id: second_installment.id,
              number: second_installment.number,
              date: Date.new(2026, 3, 10),
              month: 3,
              year: 2026,
              price: second_installment.price
            }
          ]
        }
      }, headers: turbo_stream_headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include(I18n.t("activerecord.errors.models.cash_transaction.attributes.base.paid_history_locked"))
      expect(response.body).to include(I18n.t("notification.history_workarounds.paid_history_locked.cash_transaction"))
      expect(response.body).to include('data-notification-sticky-value="true"')
      expect(locked_transaction.reload.cash_installments.find_by!(number: 2).date.to_date).to eq(Date.new(2026, 4, 10))
    end

    it "shows the historical workaround when trying to unpay an old paid installment" do
      locked_transaction = create_cash_transaction_with_paid_history(description: "Old paid installment")
      first_installment = locked_transaction.cash_installments.find_by!(number: 1)
      locked_transaction.cash_installments.find_by!(number: 2)

      first_installment.update_columns(
        date: Date.new(2026, 2, 10),
        month: 2,
        year: 2026
      )
      locked_transaction.update_columns(
        date: Date.new(2026, 2, 10),
        month: 2,
        year: 2026
      )
      locked_transaction.reload
      first_installment = locked_transaction.cash_installments.find_by!(number: 1)
      second_installment = locked_transaction.cash_installments.find_by!(number: 2)

      put cash_transaction_path(locked_transaction), params: {
        cash_transaction: {
          description: locked_transaction.description,
          price: locked_transaction.price,
          date: locked_transaction.date,
          month: locked_transaction.month,
          year: locked_transaction.year,
          user_id: user.id,
          user_bank_account_id: user_bank_account.id,
          category_transactions_attributes: locked_transaction.category_transactions.map { |ct| { id: ct.id, category_id: ct.category_id } },
          entity_transactions_attributes: [],
          cash_installments_attributes: {
            "0" => {
              id: first_installment.id,
              number: first_installment.number,
              date: first_installment.date,
              month: first_installment.month,
              year: first_installment.year,
              price: first_installment.price,
              paid: false
            },
            "1" => {
              id: second_installment.id,
              number: second_installment.number,
              date: second_installment.date,
              month: second_installment.month,
              year: second_installment.year,
              price: second_installment.price,
              paid: second_installment.paid
            }
          }
        }
      }, headers: turbo_stream_headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include(I18n.t("activerecord.errors.models.cash_transaction.attributes.base.paid_history_locked"))
      expect(response.body).to include(I18n.t("notification.history_workarounds.paid_history_locked.cash_installment"))
      expect(response.body).to include('data-notification-sticky-value="true"')
      expect(first_installment.reload).to be_paid
    end

    it "shows a confirmation path and then allows a paid month-boundary correction" do
      locked_transaction = create_cash_transaction_with_paid_history(description: "Boundary correction request")
      first_installment = locked_transaction.cash_installments.find_by!(number: 1)
      second_installment = locked_transaction.cash_installments.find_by!(number: 2)

      base_params = {
        cash_transaction: {
          description: locked_transaction.description,
          price: locked_transaction.price,
          date: Date.new(2026, 4, 1),
          month: 4,
          year: 2026,
          user_id: user.id,
          user_bank_account_id: user_bank_account.id,
          category_transactions_attributes: locked_transaction.category_transactions.map { |ct| { id: ct.id, category_id: ct.category_id } },
          entity_transactions_attributes: [],
          cash_installments_attributes: {
            "0" => {
              id: first_installment.id,
              number: first_installment.number,
              date: Date.new(2026, 4, 1),
              month: 4,
              year: 2026,
              price: first_installment.price,
              paid: true
            },
            "1" => {
              id: second_installment.id,
              number: second_installment.number,
              date: second_installment.date,
              month: second_installment.month,
              year: second_installment.year,
              price: second_installment.price,
              paid: second_installment.paid
            }
          }
        }
      }

      put cash_transaction_path(locked_transaction), params: base_params, headers: turbo_stream_headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include(I18n.t("activerecord.errors.models.cash_transaction.attributes.base.month_boundary_history_correction_confirmation_required"))
      expect(response.body).to include(I18n.t("actions.confirm_historical_change"))
      expect(response.body).to include('value="2026-04-01T00:00"')

      base_params[:cash_transaction][:historical_correction_confirmation] = true

      put cash_transaction_path(locked_transaction), params: base_params, headers: turbo_stream_headers

      expect(response).to have_http_status(:ok)
      expect(locked_transaction.reload.cash_installments.find_by!(number: 1).date.to_date).to eq(Date.new(2026, 4, 1))
    end

    it "shows a confirmation path and then allows a current-month unpay" do
      today = Time.zone.today
      locked_transaction = create(
        :cash_transaction,
        user:,
        context: user.main_context,
        user_bank_account: user_bank_account,
        description: "Current month unpay request",
        price: -200,
        date: today,
        month: today.month,
        year: today.year
      )
      locked_transaction.cash_installments.destroy_all
      locked_transaction.cash_installments.create!(number: 1, price: -200, date: today, month: today.month, year: today.year, paid: true)
      locked_transaction.update_column(:cash_installments_count, 1)
      locked_transaction.categories = [ create(:category, user:, category_name: "FOOD") ]
      locked_transaction.save!

      first_installment = locked_transaction.cash_installments.find_by!(number: 1)
      base_params = {
        cash_transaction: {
          description: locked_transaction.description,
          price: locked_transaction.price,
          date: locked_transaction.date,
          month: locked_transaction.month,
          year: locked_transaction.year,
          user_id: user.id,
          user_bank_account_id: user_bank_account.id,
          category_transactions_attributes: locked_transaction.category_transactions.map { |ct| { id: ct.id, category_id: ct.category_id } },
          entity_transactions_attributes: [],
          cash_installments_attributes: {
            "0" => {
              id: first_installment.id,
              number: first_installment.number,
              date: first_installment.date,
              month: first_installment.month,
              year: first_installment.year,
              price: first_installment.price,
              paid: false
            }
          }
        }
      }

      put cash_transaction_path(locked_transaction), params: base_params, headers: turbo_stream_headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include(I18n.t("activerecord.errors.models.cash_transaction.attributes.base.same_month_paid_state_correction_confirmation_required"))
      expect(response.body).to include(I18n.t("actions.confirm_historical_change"))

      base_params[:cash_transaction][:historical_correction_confirmation] = true

      put cash_transaction_path(locked_transaction), params: base_params, headers: turbo_stream_headers

      expect(response).to have_http_status(:ok)
      expect(locked_transaction.reload.cash_installments.find_by!(number: 1)).not_to be_paid
    end

    it "allows direct structural edits on unpaid mirrored exchange return installments and mirrors them back to exchanges" do
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
      create(:exchange, entity_transaction:, bound_type: :card_bound, exchange_type: :monetary, number: 2, price: -1_000, date: Date.new(2026, 4, 20), month: 4,
                        year: 2026)

      exchange_return = first_exchange.cash_transaction&.reload
      expect(exchange_return).to be_present
      first_installment = exchange_return.cash_installments.find_by!(number: 1)
      second_installment = exchange_return.cash_installments.find_by!(number: 2)

      put cash_transaction_path(exchange_return), params: {
        cash_transaction: {
          description: exchange_return.description,
          price: exchange_return.price,
          date: exchange_return.date,
          month: exchange_return.month,
          year: exchange_return.year,
          user_id: user.id,
          user_bank_account_id: exchange_return.user_bank_account_id,
          category_transactions_attributes: exchange_return.category_transactions.map { |ct| { id: ct.id, category_id: ct.category_id } },
          entity_transactions_attributes: exchange_return.entity_transactions.to_h do |record|
            [ record.id.to_s,
              { id: record.id, entity_id: record.entity_id, is_payer: record.is_payer, price: record.price, price_to_be_returned: record.price_to_be_returned,
                exchanges_attributes: {} } ]
          end,
          cash_installments_attributes: {
            "0" => {
              id: first_installment.id,
              number: first_installment.number,
              date: first_installment.date,
              month: first_installment.month,
              year: first_installment.year,
              price: first_installment.price,
              paid: first_installment.paid
            },
            "1" => {
              id: second_installment.id,
              number: second_installment.number,
              date: second_installment.date,
              month: second_installment.month,
              year: second_installment.year,
              price: second_installment.price,
              paid: second_installment.paid
            },
            "2" => {
              number: 3,
              date: Date.new(2026, 5, 20),
              month: 5,
              year: 2026,
              price: -1_000,
              paid: false
            }
          }
        }
      }, headers: turbo_stream_headers

      expect(response).to have_http_status(:ok)
      expect(exchange_return.reload.cash_installments.count).to eq(3)
      expect(entity_transaction.reload.exchanges.count).to eq(3)
      expect(entity_transaction.reload.exchanges.order(:number).pluck(:number, :month, :year, :price)).to eq(
        [
          [ 1, 3, 2026, -1_000 ],
          [ 2, 4, 2026, -1_000 ],
          [ 3, 5, 2026, -1_000 ]
        ]
      )
    end
  end

  describe "[ context isolation ]" do
    it "keeps create, update, and destroy changes inside the derived context" do
      main_cash_transaction = create(
        :cash_transaction,
        user:,
        context: user.main_context,
        user_bank_account:,
        description: "Main isolated cash transaction",
        price: 12_000
      )
      main_cash_transaction.categories = [ category ]
      main_cash_transaction.entities = [ entity ]
      main_cash_transaction.save!

      derived_context = Logic::ContextCloneService.new(
        source_context: user.main_context,
        name: "Cash Isolation"
      ).call
      derived_cash_transaction = derived_context.cash_transactions.find_by!(description: main_cash_transaction.description)

      switch_to_context!(derived_context)

      create_params = Params::CashTransactions.new(
        cash_transaction: {
          description: "Derived only cash transaction",
          price: 15_000,
          date: Time.zone.today,
          month: Time.zone.today.month,
          year: Time.zone.today.year,
          user_id: user.id,
          user_bank_account_id: user_bank_account.id
        },
        cash_installments: { count: 1 },
        category_transactions: [ { category_id: category.id } ],
        entity_transactions: [ {
          entity_id: entity.id,
          price: 0,
          price_to_be_returned: 0,
          exchanges_attributes: []
        } ]
      )

      expect do
        post cash_transactions_path, params: create_params.params, headers: turbo_stream_headers
      end.to change { derived_context.cash_transactions.reload.count }.by(1)
                                                                      .and change { user.main_context.cash_transactions.reload.count }.by(0)

      update_params = Params::CashTransactions.new
      update_params.use_base(derived_cash_transaction, cash_transaction_options: { description: "Derived updated cash transaction", price: 18_000 })
      update_params.cash_installments.each { |installment| installment[:price] = 18_000 }

      put cash_transaction_path(derived_cash_transaction), params: update_params.params, headers: turbo_stream_headers

      expect(derived_cash_transaction.reload.description).to eq("Derived updated cash transaction")
      expect(derived_cash_transaction.price).to eq(18_000)
      expect(main_cash_transaction.reload.description).to eq("Main isolated cash transaction")
      expect(main_cash_transaction.price).to eq(12_000)

      expect do
        delete cash_transaction_path(derived_cash_transaction), headers: turbo_stream_headers
      end.to change { derived_context.cash_transactions.reload.count }.by(-1)
                                                                      .and change { user.main_context.cash_transactions.reload.count }.by(0)

      expect(CashTransaction.exists?(main_cash_transaction.id)).to be(true)
    end
  end

  describe "[ source message context isolation ]" do
    it "creates a replayed cash transaction inside the derived context and marks the message as applied" do
      other_user = create(:user, :random)
      derived_context = Logic::ContextCloneService.new(
        source_context: user.main_context,
        name: "Replay Create Isolation"
      ).call
      conversation = Conversation.find_or_create_assistant_between!(other_user, user, scenario_key: derived_context.scenario_key)
      source_message = conversation.messages.create!(
        user: other_user,
        body: "notification:create",
        headers: {
          version: "message_notification_v2",
          event: {
            action: "create",
            receiver_first_name: user.first_name,
            transaction_type: "CashTransaction",
            details: { description: "Replay create" }
          },
          replay: {
            id: 9999,
            type: "CashTransaction",
            description: "Replay create",
            price: 15_000,
            date: Time.zone.today,
            month: Time.zone.today.month,
            year: Time.zone.today.year,
            category_ids: category.id,
            entity_ids: entity.id,
            cash_installments_attributes: [
              {
                number: 1,
                date: Time.zone.today,
                month: Time.zone.today.month,
                year: Time.zone.today.year,
                price: 15_000
              }
            ],
            entity_transactions_attributes: []
          }
        }.to_json
      )

      switch_to_context!(derived_context)

      expect do
        post cash_transactions_path, params: {
          cash_transaction: {
            description: "Replay create",
            price: 15_000,
            date: Time.zone.today,
            month: Time.zone.today.month,
            year: Time.zone.today.year,
            user_id: user.id,
            user_bank_account_id: user_bank_account.id,
            category_transactions_attributes: [ { category_id: category.id } ],
            entity_transactions_attributes: [
              { entity_id: entity.id, price: 0, price_to_be_returned: 0, exchanges_attributes: [] }
            ],
            cash_installments_attributes: [
              {
                number: 1,
                date: Time.zone.today,
                month: Time.zone.today.month,
                year: Time.zone.today.year,
                price: 15_000
              }
            ],
            source_message_id: source_message.id
          }
        }, headers: turbo_stream_headers
      end.to change { derived_context.cash_transactions.reload.count }.by(1)
                                                                      .and change { user.main_context.cash_transactions.reload.count }.by(0)

      created_transaction = derived_context.cash_transactions.order(:id).last

      expect(created_transaction.context).to eq(derived_context)
      expect(created_transaction.description).to eq("Replay create")
      expect(source_message.reload.applied_at).to be_present
    end

    it "updates only the derived copy when applying a replay update message" do
      main_cash_transaction = create(
        :cash_transaction,
        user:,
        context: user.main_context,
        user_bank_account:,
        description: "Replay base transaction",
        price: 12_000
      )
      main_cash_transaction.categories = [ category ]
      main_cash_transaction.entities = [ entity ]
      main_cash_transaction.save!

      derived_context = Logic::ContextCloneService.new(
        source_context: user.main_context,
        name: "Replay Update Isolation"
      ).call
      derived_cash_transaction = derived_context.cash_transactions.find_by!(description: main_cash_transaction.description)

      other_user = create(:user, :random)
      conversation = Conversation.find_or_create_assistant_between!(other_user, user, scenario_key: derived_context.scenario_key)
      source_message = conversation.messages.create!(
        user: other_user,
        body: "notification:update",
        headers: {
          version: "message_notification_v2",
          event: {
            action: "update",
            receiver_first_name: user.first_name,
            transaction_type: "CashTransaction",
            details: { description: "Replay updated transaction" }
          },
          replay: {
            id: main_cash_transaction.id,
            type: "CashTransaction",
            description: "Replay updated transaction",
            price: 18_000,
            date: derived_cash_transaction.date,
            month: derived_cash_transaction.month,
            year: derived_cash_transaction.year
          }
        }.to_json
      )

      switch_to_context!(derived_context)

      update_params = Params::CashTransactions.new
      update_params.use_base(
        derived_cash_transaction,
        cash_transaction_options: { description: "Replay updated transaction", price: 18_000 }
      )
      update_params.cash_installments.each { |installment| installment[:price] = 18_000 }

      put cash_transaction_path(derived_cash_transaction), params: update_params.params.deep_merge(
        cash_transaction: { source_message_id: source_message.id }
      ), headers: turbo_stream_headers

      expect(derived_cash_transaction.reload.description).to eq("Replay updated transaction")
      expect(derived_cash_transaction.price).to eq(18_000)
      expect(main_cash_transaction.reload.description).to eq("Replay base transaction")
      expect(main_cash_transaction.price).to eq(12_000)
      expect(source_message.reload.applied_at).to be_present
    end

    it "ignores a source message from another scenario when creating in a derived context" do
      other_user = create(:user, :random)
      main_conversation = Conversation.find_or_create_assistant_between!(other_user, user)
      source_message = main_conversation.messages.create!(
        user: other_user,
        body: "notification:create",
        headers: {
          version: "message_notification_v2",
          event: {
            action: "create",
            receiver_first_name: user.first_name,
            transaction_type: "CashTransaction",
            details: { description: "Main replay" }
          },
          replay: {
            id: 9999,
            type: "CashTransaction",
            description: "Main replay",
            price: 15_000,
            date: Time.zone.today,
            month: Time.zone.today.month,
            year: Time.zone.today.year,
            category_ids: category.id,
            entity_ids: entity.id,
            cash_installments_attributes: [
              {
                number: 1,
                date: Time.zone.today,
                month: Time.zone.today.month,
                year: Time.zone.today.year,
                price: 15_000
              }
            ]
          }
        }.to_json
      )

      derived_context = create(:context, user:, name: "Replay Wrong Scenario", source_context: user.main_context)
      switch_to_context!(derived_context)

      expect do
        post cash_transactions_path, params: {
          cash_transaction: {
            description: "Manual create",
            price: 10_000,
            date: Time.zone.today,
            month: Time.zone.today.month,
            year: Time.zone.today.year,
            user_id: user.id,
            user_bank_account_id: user_bank_account.id,
            category_transactions_attributes: [ { category_id: category.id } ],
            entity_transactions_attributes: [
              { entity_id: entity.id, price: 0, price_to_be_returned: 0, exchanges_attributes: [] }
            ],
            cash_installments_attributes: [
              {
                number: 1,
                date: Time.zone.today,
                month: Time.zone.today.month,
                year: Time.zone.today.year,
                price: 10_000
              }
            ],
            source_message_id: source_message.id
          }
        }, headers: turbo_stream_headers
      end.to change { derived_context.cash_transactions.reload.count }.by(1)

      created_transaction = derived_context.cash_transactions.order(:id).last

      expect(created_transaction.description).to eq("Manual create")
      expect(source_message.reload.applied_at).to be_nil
    end

    it "applies an auto-routed derived scenario message only inside the receiver derived context" do
      sender = create(:user, first_name: "Rikki", email: "rikki-receiver@example.com")
      receiver = create(:user, first_name: "Gigi", email: "gigi-receiver@example.com")
      sender_context = create(:context, user: sender, source_context: sender.main_context, name: "Optimistic")
      sender_bank_account = create(:user_bank_account, user: sender, bank: create(:bank, :random))
      receiver_bank_account = create(:user_bank_account, user: receiver, bank: create(:bank, :random))
      create(:entity, user: sender, entity_name: "GIGI", entity_user: receiver)
      receiver_counterpart = create(:entity, user: receiver, entity_name: "RIKKI", entity_user: sender)

      sign_out user
      sign_in receiver

      expect do
        create(
          :cash_transaction,
          user: sender,
          context: sender_context,
          user_bank_account: sender_bank_account,
          description: "Scenario exchange",
          price: 7_500,
          date: Date.new(2026, 3, 24),
          month: 3,
          year: 2026,
          category_transactions_attributes: [
            { category_id: sender.built_in_category("EXCHANGE").id }
          ],
          cash_installments_attributes: [
            { number: 1, price: 7_500, date: Date.new(2026, 3, 24), month: 3, year: 2026 }
          ],
          entity_transactions_attributes: [
            {
              entity_id: sender.entities.that_are_users.find_by(entity_user: receiver).id,
              is_payer: true,
              price: -7_500,
              price_to_be_returned: -7_500,
              exchanges_count: 1,
              exchanges_attributes: [
                { number: 1, price: -7_500, date: Date.new(2026, 3, 28), month: 3, year: 2026 }
              ]
            }
          ]
        )
      end.to change { receiver.contexts.count }.by(1)

      receiver_context = receiver.contexts.find_by!(scenario_key: sender_context.scenario_key)
      message = Conversation.for_users([ sender.id, receiver.id ])
                            .assistant
                            .for_scenario(sender_context.scenario_key)
                            .first
                            .messages
                            .order(:id)
                            .last

      patch switch_context_path(receiver_context)

      expect do
        post cash_transactions_path, params: {
          cash_transaction: {
            description: "Scenario exchange",
            price: 7_500,
            date: Date.new(2026, 3, 28),
            month: 3,
            year: 2026,
            user_id: receiver.id,
            user_bank_account_id: receiver_bank_account.id,
            category_transactions_attributes: [
              { category_id: receiver.built_in_category("EXCHANGE").id }
            ],
            entity_transactions_attributes: [
              {
                entity_id: receiver_counterpart.id,
                is_payer: true,
                price: -7_500,
                price_to_be_returned: -7_500,
                exchanges_count: 1,
                exchanges_attributes: [
                  { number: 1, price: -7_500, date: Date.new(2026, 3, 28), month: 3, year: 2026 }
                ]
              }
            ],
            cash_installments_attributes: [
              {
                number: 1,
                date: Date.new(2026, 3, 28),
                month: 3,
                year: 2026,
                price: 7_500
              }
            ],
            source_message_id: message.id
          }
        }, headers: turbo_stream_headers
      end.to change { receiver_context.cash_transactions.reload.count }.by(1)
                                                                       .and change { receiver.main_context.cash_transactions.reload.count }.by(0)

      created_transaction = receiver_context.cash_transactions.order(:id).last

      expect(created_transaction.context).to eq(receiver_context)
      expect(created_transaction.description).to eq("Scenario exchange")
      expect(message.reload.applied_at).to be_present
    end
  end

  describe "[ cross-context access denial ]" do
    it "does not allow editing, updating, or destroying a main-context cash transaction while in a derived context" do
      main_cash_transaction = create(
        :cash_transaction,
        user:,
        context: user.main_context,
        user_bank_account:,
        description: "Main inaccessible cash transaction",
        price: 12_000
      )

      derived_context = Logic::ContextCloneService.new(
        source_context: user.main_context,
        name: "Cash Access Isolation"
      ).call

      switch_to_context!(derived_context)

      get edit_cash_transaction_path(main_cash_transaction)
      expect(response).to have_http_status(:not_found)

      patch cash_transaction_path(main_cash_transaction), params: {
        cash_transaction: {
          description: "Should not update",
          price: main_cash_transaction.price,
          date: main_cash_transaction.date,
          month: main_cash_transaction.month,
          year: main_cash_transaction.year,
          user_id: user.id,
          user_bank_account_id: user_bank_account.id,
          cash_installments_attributes: main_cash_transaction.cash_installments.map do |installment|
            {
              id: installment.id,
              number: installment.number,
              date: installment.date,
              month: installment.month,
              year: installment.year,
              price: installment.price
            }
          end
        }
      }, headers: turbo_stream_headers
      expect(response).to have_http_status(:not_found)

      delete cash_transaction_path(main_cash_transaction), headers: turbo_stream_headers
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "[ shared paid state sync ]" do
    around do |example|
      perform_enqueued_jobs { example.run }
    end

    it "synchronizes a shared return back to not paid and informs through the assistant thread" do
      sender = create(:user, first_name: "Rikki", email: "rikki-paid-sync@example.com")
      receiver = create(:user, first_name: "Gigi", email: "gigi-paid-sync@example.com")
      sender_transaction, receiver_transaction = create_shared_return_pair(sender:, receiver:)

      sign_out user
      sign_in receiver

      patch cash_transaction_path(receiver_transaction), params: {
        cash_transaction: {
          description: receiver_transaction.description,
          comment: receiver_transaction.comment,
          price: receiver_transaction.price,
          date: receiver_transaction.date,
          month: receiver_transaction.month,
          year: receiver_transaction.year,
          user_id: receiver.id,
          user_bank_account_id: receiver_transaction.user_bank_account_id,
          category_transactions_attributes: receiver_transaction.category_transactions.map { |record| { id: record.id, category_id: record.category_id } },
          entity_transactions_attributes: receiver_transaction.entity_transactions.map do |record|
            { id: record.id, entity_id: record.entity_id, is_payer: record.is_payer, price: record.price, price_to_be_returned: record.price_to_be_returned,
              exchanges_attributes: [] }
          end,
          cash_installments_attributes: [
            {
              id: receiver_transaction.cash_installments.first.id,
              number: 1,
              date: receiver_transaction.cash_installments.first.date,
              month: receiver_transaction.cash_installments.first.month,
              year: receiver_transaction.cash_installments.first.year,
              price: receiver_transaction.cash_installments.first.price,
              paid: false
            }
          ]
        }
      }, headers: turbo_stream_headers

      conversation = Conversation.for_users([ receiver.id, sender.id ]).assistant.order(:id).last

      expect(response).to have_http_status(:ok)
      expect(receiver_transaction.cash_installments.first.reload).not_to be_paid
      expect(sender_transaction.cash_installments.first.reload).not_to be_paid
      expect(conversation).to be_present
      message = conversation.messages.order(:id).last
      expect(message.body).to eq("notification:paid_state")
      expect(message.conversation).to be_assistant
      expect(message.conversation.users).to match_array([ receiver, sender ])
      expect(JSON.parse(message.headers)).to include(
        "version" => "message_paid_state_v1",
        "event" => include("action" => "unpaid")
      )
    end

    it "accepts the standard nested hash payload shape when no paid state changed" do
      sender = create(:user, first_name: "Rikki", email: "rikki-paid-noop@example.com")
      receiver = create(:user, first_name: "Gigi", email: "gigi-paid-noop@example.com")
      _sender_transaction, receiver_transaction = create_shared_return_pair(sender:, receiver:)

      sign_out user
      sign_in receiver

      installment = receiver_transaction.cash_installments.first

      patch cash_transaction_path(receiver_transaction), params: {
        cash_transaction: {
          description: receiver_transaction.description,
          comment: receiver_transaction.comment,
          price: receiver_transaction.price,
          date: receiver_transaction.date,
          month: receiver_transaction.month,
          year: receiver_transaction.year,
          user_id: receiver.id,
          user_bank_account_id: receiver_transaction.user_bank_account_id,
          category_transactions_attributes: receiver_transaction.category_transactions.map { |record| { id: record.id, category_id: record.category_id } },
          entity_transactions_attributes: receiver_transaction.entity_transactions.to_h do |record|
            [
              record.id.to_s,
              {
                id: record.id,
                entity_id: record.entity_id,
                is_payer: record.is_payer,
                price: record.price,
                price_to_be_returned: record.price_to_be_returned,
                exchanges_attributes: {}
              }
            ]
          end,
          cash_installments_attributes: {
            "0" => {
              id: installment.id,
              number: installment.number,
              date: installment.date,
              month: installment.month,
              year: installment.year,
              price: installment.price,
              paid: installment.paid
            }
          }
        }
      }, headers: turbo_stream_headers

      expect(response).to have_http_status(:ok)
      expect(Message.where(body: "notification:paid_state")).to be_empty
      expect(receiver_transaction.reload.cash_installments.first).to be_paid
    end
  end

  describe "[ exchange return counterpart notifications ]" do
    it "creates an actionable update message when unpaid mirrored installments change structurally" do
      receiver = create(:user, :random)
      receiver_entity = create(:entity, user:, entity_name: receiver.first_name.upcase, entity_user: receiver)
      create(:entity, user: receiver, entity_name: user.first_name.upcase, entity_user: user)
      card = create(:card, :random, bank: bank)
      user_card = create(:user_card, :random, user:, card:)
      card_transaction = create(
        :card_transaction,
        user:,
        context: user.main_context,
        user_card:,
        description: "Mirror source",
        date: Date.new(2026, 3, 10),
        month: 4,
        year: 2026,
        price: -3_000
      )
      card_transaction.category_transactions.destroy_all
      card_transaction.category_transactions.create!(category: user.built_in_category("EXCHANGE"))
      entity_transaction = card_transaction.entity_transactions.first
      entity_transaction.update!(entity_id: receiver_entity.id, price: -3_000, price_to_be_returned: -3_000, is_payer: true, exchanges_count: 3)
      first_exchange = create(:exchange, entity_transaction:, bound_type: :card_bound, exchange_type: :monetary, number: 1, price: -1_000,
                                         date: Date.new(2026, 4, 10), month: 4, year: 2026)
      create(:exchange, entity_transaction:, bound_type: :card_bound, exchange_type: :monetary, number: 2, price: -1_000, date: Date.new(2026, 5, 10), month: 5,
                        year: 2026)
      create(:exchange, entity_transaction:, bound_type: :card_bound, exchange_type: :monetary, number: 3, price: -1_000, date: Date.new(2026, 6, 10), month: 6,
                        year: 2026)
      exchange_return = first_exchange.cash_transaction.reload

      expect do
        patch cash_transaction_path(exchange_return), params: {
          cash_transaction: {
            description: exchange_return.description,
            comment: exchange_return.comment,
            price: -3_000,
            date: exchange_return.date,
            month: exchange_return.month,
            year: exchange_return.year,
            user_id: user.id,
            user_bank_account_id: exchange_return.user_bank_account_id,
            category_transactions_attributes: exchange_return.category_transactions.map { |record| { id: record.id, category_id: record.category_id } },
            entity_transactions_attributes: exchange_return.entity_transactions.map do |record|
              { id: record.id, entity_id: record.entity_id, is_payer: record.is_payer, price: record.price, price_to_be_returned: record.price_to_be_returned,
                exchanges_attributes: [] }
            end,
            cash_installments_attributes: [
              {
                id: exchange_return.cash_installments.find_by!(number: 1).id,
                number: 1,
                date: exchange_return.cash_installments.find_by!(number: 1).date,
                month: 4,
                year: 2026,
                price: -1_000,
                paid: false
              },
              {
                id: exchange_return.cash_installments.find_by!(number: 2).id,
                number: 2,
                date: exchange_return.cash_installments.find_by!(number: 2).date,
                month: 5,
                year: 2026,
                price: -1_000,
                paid: false
              },
              {
                id: exchange_return.cash_installments.find_by!(number: 3).id,
                number: 3,
                date: exchange_return.cash_installments.find_by!(number: 3).date,
                month: 6,
                year: 2026,
                price: -500,
                paid: false
              },
              {
                number: 4,
                date: Time.zone.local(2026, 7, 10, 0, 0, 0),
                month: 7,
                year: 2026,
                price: -500,
                paid: false
              }
            ]
          }
        }, headers: turbo_stream_headers
      end.to change(Message.where(body: "notification:update"), :count).by(1)

      message = Message.where(body: "notification:update").order(:id).last

      expect(response).to have_http_status(:ok)
      expect(message.user).to eq(user)
      expect(message.conversation.users).to match_array([ user, receiver ])
      expect(JSON.parse(message.headers)).to include(
        "version" => "message_notification_v2",
        "event" => include("action" => "update")
      )
    end
  end

  describe "[ form context isolation ]" do
    it "renders only bound card transactions from the current context on exchange return edit" do
      exchange_return_category = user.built_in_category("EXCHANGE RETURN")
      main_card_transaction = create(
        :card_transaction,
        user:,
        context: user.main_context,
        user_card: create(:user_card, :random, user:, card: create(:card, :random, bank: bank)),
        description: "Main Bound Card",
        date: Date.new(2026, 2, 10),
        month: 3,
        year: 2026,
        price: -1000,
        paid: false
      )
      main_exchange_return = create(
        :cash_transaction,
        user:,
        context: user.main_context,
        user_bank_account:,
        user_card: main_card_transaction.user_card,
        description: "Shared Exchange Return",
        cash_transaction_type: "Exchange",
        date: Date.new(2026, 3, 12),
        month: 3,
        year: 2026,
        price: -1000,
        paid: false
      )
      main_exchange_return.categories = [ exchange_return_category ]
      main_exchange_return.save!
      main_entity_transaction = main_card_transaction.entity_transactions.first
      main_entity_transaction.update!(price: -1000, price_to_be_returned: -1000, is_payer: true, exchanges_count: 1)
      create(:exchange, entity_transaction: main_entity_transaction, cash_transaction: main_exchange_return, number: 1, month: 3, year: 2026,
                        date: Date.new(2026, 3, 12), price: -1000)

      derived_context = Logic::ContextCloneService.new(source_context: user.main_context, name: "Cash Form Isolation").call
      derived_exchange_return = derived_context.cash_transactions.find_by!(description: "Shared Exchange Return")
      derived_card_transaction = derived_context.card_transactions.find_by!(description: "Main Bound Card")
      derived_card_transaction.update!(description: "Derived Bound Card")

      switch_to_context!(derived_context)

      get edit_cash_transaction_path(derived_exchange_return)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Derived Bound Card")
      expect(response.body).not_to include("Main Bound Card")
    end
  end

  describe "[ #destroy ]" do
    before do
      cash_transaction.date = 1.month.from_now.to_date
      cash_transaction.month = cash_transaction.date.month
      cash_transaction.year = cash_transaction.date.year
      post cash_transactions_path, params: cash_transaction.params, headers: turbo_stream_headers
      @existing_cash_transaction = CashTransaction.last
    end

    it "destroys the record and its installments" do
      cash_installment_ids = @existing_cash_transaction.cash_installments.ids

      expect { delete cash_transaction_path(@existing_cash_transaction), headers: turbo_stream_headers }.to change(CashTransaction, :count).by(-1)

      expect(CashInstallment.where(id: cash_installment_ids)).to be_empty
    end

    it "marks the source message as applied when destroying from a message" do
      other_user = create(:user, :random)
      conversation = Conversation.create!.tap do |record|
        record.conversation_participants.create!(user:)
        record.conversation_participants.create!(user: other_user)
      end
      source_message = conversation.messages.create!(
        user: other_user,
        body: "notification:destroy",
        reference_transactable: @existing_cash_transaction,
        headers: {
          version: "message_notification_v2",
          event: {
            action: "destroy",
            receiver_first_name: user.first_name,
            transaction_type: "CashTransaction",
            details: { description: "Salary payment" }
          },
          replay: nil
        }.to_json
      )

      delete cash_transaction_path(@existing_cash_transaction, message_id: source_message.id), headers: turbo_stream_headers

      expect(source_message.reload.applied_at).to be_present
    end

    it "returns unprocessable_entity when destroying a transaction with paid history" do
      locked_transaction = create_cash_transaction_with_paid_history(description: "Locked destroy cash")

      expect do
        delete cash_transaction_path(locked_transaction), headers: turbo_stream_headers
      end.not_to change(CashTransaction, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include(I18n.t("activerecord.errors.models.cash_transaction.attributes.base.destroy_locked_after_payment"))
      expect(response.body).to include(I18n.t("notification.history_workarounds.destroy_locked_after_payment"))
      expect(locked_transaction.reload).to be_present
    end

    it "does not mark the source message as applied when guarded destroy fails" do
      locked_transaction = create_cash_transaction_with_paid_history(description: "Locked destroy replay")
      other_user = create(:user, :random)
      conversation = Conversation.create!.tap do |record|
        record.conversation_participants.create!(user:)
        record.conversation_participants.create!(user: other_user)
      end
      source_message = conversation.messages.create!(
        user: other_user,
        body: "notification:destroy",
        reference_transactable: locked_transaction,
        headers: {
          version: "message_notification_v2",
          event: {
            action: "destroy",
            receiver_first_name: user.first_name,
            transaction_type: "CashTransaction",
            details: { description: locked_transaction.description }
          },
          replay: nil
        }.to_json
      )

      delete cash_transaction_path(locked_transaction, message_id: source_message.id), headers: turbo_stream_headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include(I18n.t("activerecord.errors.models.cash_transaction.attributes.base.destroy_locked_after_payment"))
      expect(response.body).to include(I18n.t("notification.history_workarounds.destroy_locked_after_payment"))
      expect(source_message.reload.applied_at).to be_nil
      expect(locked_transaction.reload).to be_present
    end
  end

  describe "[ #month_year ]" do
    it "responds successfully for an existing month_year" do
      post cash_transactions_path, params: cash_transaction.params, headers: turbo_stream_headers
      month_year = Time.zone.today.strftime("%Y%m")

      get month_year_cash_transactions_path, params: {
        month_year:,
        cash_transaction: { user_bank_account_id: user_bank_account.id }
      }

      follow_redirect! if response.redirect?
      expect(response).to have_http_status(:success)
    end
  end
end
