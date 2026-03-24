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
  end

  describe "[ #update ]" do
    before do
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
