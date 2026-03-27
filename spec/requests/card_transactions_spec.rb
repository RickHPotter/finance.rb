# frozen_string_literal: true

require "rails_helper"

RSpec.describe "CardTransactions", type: :request do
  let(:bank) { create(:bank, :random) }
  let(:user) { create(:user, :random) }
  let(:card) { create(:card, :random, bank:) }
  let(:user_card_one) { create(:user_card, :random, user:, card:, user_card_name: "Gaara", due_date_day: Time.zone.today.day) }
  let(:user_card_two) { create(:user_card, :random, user:, card:, user_card_name: "Jiraiya", due_date_day: Time.zone.today.day) }
  let(:exchange_category) { user.built_in_category("EXCHANGE") }
  let(:entity_one) { create(:entity, :random, user:) }
  let(:entity_two) { create(:entity, :random, user:) }
  let(:subscription) { create(:subscription, user:) }

  let(:card_transaction) do
    Params::CardTransactions.new(
      card_transaction: {
        price: -20_000,
        date: Time.zone.today,
        month: Time.zone.today.month,
        year: Time.zone.today.year,
        user_id: user.id,
        user_card_id: user_card_one.id,
        subscription_id: subscription.id
      },
      card_installments: { count: 1 },
      category_transactions: [],
      entity_transactions: [ {
        entity_id: entity_one.id, price: -2200, price_to_be_returned: -2200,
        exchanges_attributes: [ { price: -2200, exchange_type: :monetary, date: Time.zone.today, month: Time.zone.today.month, year: Time.zone.today.year } ]
      } ]
    )
  end

  def check_paying_entities(card_transaction)
    expect(card_transaction.paying_entities).to be_present
    expect(card_transaction.paying_transactions.flat_map(&:exchanges)).to be_present
    expect(card_transaction.built_in_categories_by(category_name: "EXCHANGE")).to be_present
  end

  def check_non_paying_entities(card_transaction)
    expect(card_transaction.non_paying_entities).to be_present
    expect(card_transaction.non_paying_transactions).to be_present
    expect(card_transaction.non_paying_transactions.flat_map(&:exchanges)).to be_empty
    expect(card_transaction.built_in_categories_by(category_name: "EXCHANGE")).to_not be_present
  end

  def check_card_installments(card_installments)
    installments_by_month_year = card_installments.group_by(&:month_year)

    installments_by_month_year.each_pair do |month_year, installments_collection|
      expect(installments_collection.pluck(:cash_transaction_id).uniq.count).to eq(1)
      expect(installments_collection.map(&:month_year).uniq).to eq([ month_year ])
      expect(installments_collection.sum(&:price)).to be >= installments_collection.first.cash_transaction.price
    end
  end

  def check_exchanges(exchanges)
    exchanges.each do |exchange|
      expect(exchange.cash_transaction.present?).to be(exchange.monetary?)
    end
  end

  before { sign_in user }

  def switch_to_context!(context)
    patch switch_context_path(context)
    expect(response).to redirect_to(root_path)
  end

  def create_card_transaction_with_paid_history(description: "Locked card transaction") # rubocop:disable Metrics/AbcSize
    transaction = create(
      :card_transaction,
      user:,
      context: user.main_context,
      user_card: user_card_one,
      description:,
      price: -3_000,
      date: Date.new(2026, 3, 10),
      month: 4,
      year: 2026
    )
    stale_cash_transaction_ids = transaction.card_installments.pluck(:cash_transaction_id).compact
    transaction.card_installments.delete_all
    Installment.where(cash_transaction_id: stale_cash_transaction_ids).delete_all
    CashTransaction.where(id: stale_cash_transaction_ids).delete_all
    installments = [
      { number: 1, price: -1_000, date: Time.zone.local(2026, 3, 10, 12), month: 3, year: 2026, paid: true },
      { number: 2, price: -1_000, date: Time.zone.local(2026, 4, 10, 12), month: 4, year: 2026, paid: false },
      { number: 3, price: -1_000, date: Time.zone.local(2026, 5, 10, 12), month: 5, year: 2026, paid: false }
    ]
    installments.each { |attrs| transaction.card_installments.create!(attrs.merge(paid: false)) }
    transaction.card_installments.order(:number).zip(installments).each do |installment, attrs|
      installment.update_columns(price: attrs[:price], date: attrs[:date], month: attrs[:month], year: attrs[:year], paid: attrs[:paid])
    end
    transaction.update_column(:card_installments_count, 3)
    transaction.category_transactions.destroy_all
    transaction.category_transactions.create!(category: create(:category, user:, category_name: "FOOD"))
    transaction.reload
  end

  def create_card_advance_transaction(price: 200, date: Time.zone.today)
    post pay_in_advance_card_transactions_path, params: {
      card_transaction: {
        user_card_id: user_card_one.id,
        date:,
        month: date.month,
        year: date.year,
        price:
      }
    }, headers: turbo_stream_headers

    CardTransaction.last
  end

  def create_card_transaction_with_locked_exchange_projection(description: "Locked exchange projection")
    transaction = create(
      :card_transaction,
      user:,
      context: user.main_context,
      user_card: user_card_one,
      description:,
      price: -2_200,
      date: Date.new(2026, 3, 10),
      month: 4,
      year: 2026
    )
    stale_cash_transaction_ids = transaction.card_installments.pluck(:cash_transaction_id).compact
    transaction.card_installments.delete_all
    Installment.where(cash_transaction_id: stale_cash_transaction_ids).delete_all
    CashTransaction.where(id: stale_cash_transaction_ids).delete_all
    exchange = attach_locked_exchange_projection(transaction)
    exchange.cash_transaction.cash_installments.first.update!(paid: true)
    transaction.reload
  end

  def create_card_transaction_with_paid_invoice_target
    paid_cycle_transaction = create(
      :card_transaction,
      user:,
      context: user.main_context,
      user_card: user_card_one,
      description: "Paid cycle anchor",
      price: -1_000,
      date: Date.new(2026, 2, 10),
      month: 3,
      year: 2026
    )
    paid_invoice = paid_cycle_transaction.card_installments.first.cash_transaction
    paid_invoice.cash_installments.first.update!(paid: true)
    paid_invoice.update_column(:paid, true)

    movable_transaction = create(
      :card_transaction,
      user:,
      context: user.main_context,
      user_card: user_card_one,
      description: "Move me later",
      price: -2_000,
      date: Date.new(2026, 4, 10),
      month: 5,
      year: 2026
    )

    [ movable_transaction.reload, paid_invoice.reload ]
  end

  def attach_locked_exchange_projection(transaction)
    transaction.category_transactions.destroy_all
    transaction.entity_transactions.destroy_all
    transaction.category_transactions.create!(category: exchange_category)

    entity_transaction = transaction.entity_transactions.create!(
      entity: entity_one,
      is_payer: true,
      price: -2_200,
      price_to_be_returned: -2_200,
      exchanges_count: 1
    )

    create(
      :exchange,
      entity_transaction:,
      exchange_type: :monetary,
      number: 1,
      price: -2_200,
      date: Date.new(2026, 3, 20),
      month: 3,
      year: 2026
    )
  end

  describe "[ #create ]" do
    it "creates one new record with one installment and non-paying entities" do
      card_transaction.entity_transactions = [ { entity_id: entity_one.id, price: -2200, exchanges_attributes: [] } ]
      expect { post card_transactions_path, params: card_transaction.params, headers: turbo_stream_headers }.to change(CardTransaction, :count).by(1)
      new_card_transaction = CardTransaction.last

      expect(new_card_transaction.subscription).to eq(subscription)
      check_non_paying_entities(new_card_transaction)
      check_card_installments(new_card_transaction.card_installments)
      expect(subscription.reload.price).to eq(-20_000)
    end

    it "creates one new record with two installments and two paying entities" do
      card_transaction.card_installments = { count: 2 }
      card_transaction.category_transactions = [ { category_id: exchange_category.id } ]
      card_transaction.entity_transactions = [
        {
          entity_id: entity_one.id,
          price: -2200,
          price_to_be_returned: -2200,
          exchanges_attributes: [ { price: -2200, exchange_type: :monetary, date: Time.zone.today, month: Time.zone.today.month, year: Time.zone.today.year } ]
        },
        {
          entity_id: entity_two.id,
          price: -2200,
          price_to_be_returned: -2200,
          exchanges_attributes: [ { price: -2200, exchange_type: :monetary, date: Time.zone.today, month: Time.zone.today.month, year: Time.zone.today.year } ]
        }
      ]

      expect { post card_transactions_path, params: card_transaction.params, headers: turbo_stream_headers }.to change(CardTransaction, :count).by(1)
      new_card_transaction = CardTransaction.last

      check_paying_entities(new_card_transaction)
      check_card_installments(new_card_transaction.card_installments)
    end

    it "creates two new records, each with two installments that overlap months, and two paying entities" do
      card_transaction.card_installments = { count: 2 }
      card_transaction.category_transactions = [ { category_id: exchange_category.id } ]
      card_transaction.entity_transactions = [
        {
          entity_id: entity_one.id,
          price: -2200,
          price_to_be_returned: -2200,
          exchanges_attributes: [ { price: -2200, exchange_type: :monetary, date: Time.zone.today, month: Time.zone.today.month, year: Time.zone.today.year } ]
        },
        {
          entity_id: entity_two.id,
          price: -2200,
          price_to_be_returned: -2200,
          exchanges_attributes: [ { price: -2200, exchange_type: :monetary, date: Time.zone.today, month: Time.zone.today.month, year: Time.zone.today.year } ]
        }
      ]

      expect { post card_transactions_path, params: card_transaction.params, headers: turbo_stream_headers }.to change(CardTransaction, :count).by(1)
      card_transaction_one = CardTransaction.last

      sign_in user

      card_transaction.date += 40.days # 1 month is sometimes not enough
      expect { post card_transactions_path, params: card_transaction.params, headers: turbo_stream_headers }.to change(CardTransaction, :count).by(1)
      card_transaction_two = CardTransaction.last

      check_paying_entities(card_transaction_one)
      check_paying_entities(card_transaction_two)
      check_card_installments([ *card_transaction_one.card_installments, *card_transaction_two.card_installments ])
    end

    it "reuses the existing card-bound EXCHANGE RETURN cash transaction for the same card, entity, and month" do
      card_transaction.card_installments = { count: 1 }
      card_transaction.category_transactions = [ { category_id: exchange_category.id } ]
      card_transaction.entity_transactions = [
        {
          entity_id: entity_one.id,
          price: -2200,
          price_to_be_returned: -2200,
          exchanges_attributes: [ { price: -2200, exchange_type: :monetary, date: Time.zone.today, month: Time.zone.today.month, year: Time.zone.today.year } ]
        }
      ]

      post card_transactions_path, params: card_transaction.params, headers: turbo_stream_headers
      first_card_transaction = CardTransaction.last
      first_exchange_return_id = first_card_transaction.entity_transactions.first.exchanges.first.cash_transaction_id

      sign_in user

      second_params = Params::CardTransactions.new(
        card_transaction: {
          price: -2_899,
          date: Time.zone.today,
          month: Time.zone.today.month,
          year: Time.zone.today.year,
          user_id: user.id,
          user_card_id: user_card_one.id
        },
        card_installments: { count: 1 },
        category_transactions: [ { category_id: exchange_category.id } ],
        entity_transactions: [ {
          entity_id: entity_one.id,
          price: -2_899,
          price_to_be_returned: -2_899,
          exchanges_attributes: [ { price: -2_899, exchange_type: :monetary, date: Time.zone.today, month: Time.zone.today.month, year: Time.zone.today.year } ]
        } ]
      )

      expect { post card_transactions_path, params: second_params.params, headers: turbo_stream_headers }.to change(CardTransaction, :count).by(1)

      second_card_transaction = CardTransaction.last
      second_exchange_return_id = second_card_transaction.entity_transactions.first.exchanges.first.cash_transaction_id
      shared_exchange_return = CashTransaction.find(first_exchange_return_id)

      expect(second_exchange_return_id).to eq(first_exchange_return_id)
      expect(shared_exchange_return.cash_installments.order(:number).pluck(:price)).to eq([ -5099 ])
      expect(shared_exchange_return.exchanges.card_bound.order(:number, :date).pluck(:price)).to eq([ -2200, -2899 ])
    end
  end

  describe "[ #update ]" do
    before do
      card_transaction.entity_transactions = [ { entity_id: entity_one.id, price: -2200, price_to_be_returned: -2200, exchanges_attributes: [] } ]
      post card_transactions_path, params: card_transaction.params, headers: turbo_stream_headers
      @existing_card_transaction = CardTransaction.last

      sign_in user
    end

    it "updates the record to have a non_paying entity" do
      card_transaction.use_base(@existing_card_transaction, entity_transactions_options: { is_payer: false })
      put(card_transaction_path(@existing_card_transaction), params: card_transaction.params, headers: turbo_stream_headers)
      check_non_paying_entities(@existing_card_transaction)
    end

    it "updates the record to have one paying entity" do
      card_transaction.use_base(@existing_card_transaction, entity_transactions_options: { is_payer: true, exchange_type: :monetary })
      card_transaction.category_transactions = [ { category_id: exchange_category.id } ]
      put(card_transaction_path(@existing_card_transaction), params: card_transaction.params, headers: turbo_stream_headers)
      check_paying_entities(@existing_card_transaction)
    end

    it "updates the record to change the exchange_type to :non_monetary then to :monetary" do
      card_transaction.use_base(@existing_card_transaction, entity_transactions_options: { is_payer: true, exchange_type: :non_monetary })
      put(card_transaction_path(@existing_card_transaction), params: card_transaction.params, headers: turbo_stream_headers)
      check_exchanges(@existing_card_transaction.entity_transactions.first.exchanges)

      sign_in user

      card_transaction.use_base(@existing_card_transaction, entity_transactions_options: { is_payer: true, exchange_type: :monetary })
      put(card_transaction_path(@existing_card_transaction), params: card_transaction.params, headers: turbo_stream_headers)
      check_exchanges(@existing_card_transaction.entity_transactions.first.exchanges)
    end

    it "updates the record to change the exchange_type to :monetary then to :non_monetary" do
      card_transaction.use_base(@existing_card_transaction, entity_transactions_options: { is_payer: true, exchange_type: :monetary })
      put(card_transaction_path(@existing_card_transaction), params: card_transaction.params, headers: turbo_stream_headers)
      check_exchanges(@existing_card_transaction.entity_transactions.first.exchanges)

      sign_in user

      card_transaction.use_base(@existing_card_transaction, entity_transactions_options: { is_payer: true, exchange_type: :non_monetary })
      put(card_transaction_path(@existing_card_transaction), params: card_transaction.params, headers: turbo_stream_headers)
      check_exchanges(@existing_card_transaction.entity_transactions.first.exchanges)
    end

    it "updates the record accordingly given a change in the card_transaction FKs" do
      cash_transaction_one = @existing_card_transaction.card_installments.first.cash_transaction

      card_transaction.use_base(@existing_card_transaction, card_transaction_options: { user_card_id: user_card_two.id })
      put(card_transaction_path(@existing_card_transaction), params: card_transaction.params, headers: turbo_stream_headers)

      cash_transaction_two = @existing_card_transaction.card_installments.first.cash_transaction

      expect(cash_transaction_one).to_not eq cash_transaction_two
      expect(CashTransaction.exists?(cash_transaction_one.id)).to be_falsey
      expect(CashTransaction.exists?(cash_transaction_two.id)).to be_truthy
    end

    it "updates the linked subscription" do
      other_subscription = create(:subscription, user:)
      card_transaction.use_base(@existing_card_transaction, card_transaction_options: { subscription_id: other_subscription.id })

      put(card_transaction_path(@existing_card_transaction), params: card_transaction.params, headers: turbo_stream_headers)

      expect(@existing_card_transaction.reload.subscription).to eq(other_subscription)
      expect(subscription.reload.price).to eq(0)
      expect(other_subscription.reload.price).to eq(-20_000)
    end

    it "returns unprocessable_entity when a paid-history rewrite is blocked" do
      locked_transaction = create_card_transaction_with_paid_history
      second_installment = locked_transaction.card_installments.find_by!(number: 2)

      put card_transaction_path(locked_transaction), params: {
        card_transaction: {
          description: locked_transaction.description,
          price: locked_transaction.price,
          date: locked_transaction.date,
          month: locked_transaction.month,
          year: locked_transaction.year,
          user_id: user.id,
          user_card_id: user_card_one.id,
          category_transactions_attributes: locked_transaction.category_transactions.map { |ct| { id: ct.id, category_id: ct.category_id } },
          entity_transactions_attributes: [],
          card_installments_attributes: [
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
      expect(response.body).to include(I18n.t("activerecord.errors.models.card_transaction.attributes.base.paid_history_locked"))
      expect(response.body).to include(I18n.t("notification.history_workarounds.paid_history_locked.card_transaction"))
      expect(response.body).to include('data-notification-sticky-value="true"')
      expect(locked_transaction.reload.card_installments.find_by!(number: 2).date.to_date).to eq(Date.new(2026, 4, 10))
    end

    it "shows a confirmation path and then allows a same-cycle paid date correction" do
      locked_transaction = create_card_transaction_with_paid_history(description: "Cycle correction request")
      first_installment = locked_transaction.card_installments.find_by!(number: 1)

      base_params = {
        card_transaction: {
          description: locked_transaction.description,
          price: locked_transaction.price,
          date: locked_transaction.date,
          month: locked_transaction.month,
          year: locked_transaction.year,
          user_id: user.id,
          user_card_id: user_card_one.id,
          category_transactions_attributes: locked_transaction.category_transactions.map { |ct| { id: ct.id, category_id: ct.category_id } },
          entity_transactions_attributes: [],
          card_installments_attributes: [
            {
              id: first_installment.id,
              number: first_installment.number,
              date: Date.new(2026, 3, 25),
              month: first_installment.month,
              year: first_installment.year,
              price: first_installment.price
            }
          ]
        }
      }

      put card_transaction_path(locked_transaction), params: base_params, headers: turbo_stream_headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include(I18n.t("activerecord.errors.models.card_transaction.attributes.base.same_cycle_history_correction_confirmation_required"))
      expect(response.body).to include(I18n.t("actions.confirm_historical_change"))
      expect(response.body).to include('value="2026-03-25T00:00"')

      base_params[:card_transaction][:historical_correction_confirmation] = true

      put card_transaction_path(locked_transaction), params: base_params, headers: turbo_stream_headers

      expect(response).to have_http_status(:ok)
      expect(locked_transaction.reload.card_installments.find_by!(number: 1).date.to_date).to eq(Date.new(2026, 3, 25))
    end

    it "returns unprocessable_content when updating a card advance with a locked linked cash transaction" do
      advanced_card_transaction = create_card_advance_transaction
      advance_cash_transaction = advanced_card_transaction.advance_cash_transaction
      params = Params::CardTransactions.new
      params.use_base(advanced_card_transaction, card_transaction_options: { price: 350 })
      params.card_installments.each { |installment| installment[:price] = 350 }

      put card_transaction_path(advanced_card_transaction), params: params.params, headers: turbo_stream_headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include(I18n.t("activerecord.errors.models.card_transaction.attributes.base.paid_history_locked"))
      expect(response.body).to include(I18n.t("notification.history_workarounds.paid_history_locked.card_transaction"))
      expect(advanced_card_transaction.reload.price).to eq(200)
      expect(advance_cash_transaction.reload.price).to eq(-200)
    end

    it "returns unprocessable_content when updating an exchange with a locked mirrored return" do
      locked_transaction = create_card_transaction_with_locked_exchange_projection
      exchange = locked_transaction.entity_transactions.first.exchanges.first
      params = Params::CardTransactions.new
      params.use_base(locked_transaction)
      params.entity_transactions.first[:exchanges_attributes].first[:price] = -2_500

      put card_transaction_path(locked_transaction), params: params.params, headers: turbo_stream_headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include(I18n.t("activerecord.errors.models.exchange.attributes.base.paid_history_locked"))
      expect(response.body).to include(I18n.t("notification.history_workarounds.paid_history_locked.default"))
      expect(exchange.reload.price).to eq(-2_200)
      expect(exchange.cash_transaction.reload.price).to eq(-2_200)
    end

    it "returns unprocessable_content when moving an unpaid card transaction into a paid invoice cycle" do
      movable_transaction, paid_invoice = create_card_transaction_with_paid_invoice_target
      original_cash_transaction = movable_transaction.card_installments.first.cash_transaction
      original_month = movable_transaction.card_installments.first.month
      original_year = movable_transaction.card_installments.first.year
      params = Params::CardTransactions.new
      params.use_base(movable_transaction)
      params.card_installments.first[:date] = Date.new(2026, 2, 10)
      params.card_installments.first[:month] = 3
      params.card_installments.first[:year] = 2026

      put card_transaction_path(movable_transaction), params: params.params, headers: turbo_stream_headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include(I18n.t("activerecord.errors.models.card_transaction.attributes.base.paid_history_locked"))
      expect(response.body).to include(I18n.t("notification.history_workarounds.paid_history_locked.card_transaction"))
      expect(paid_invoice.reload.price).to eq(-1_000)
      expect(paid_invoice.cash_installments.first.reload.price).to eq(-1_000)
      expect(movable_transaction.reload.card_installments.first.cash_transaction).to eq(original_cash_transaction)
      expect(movable_transaction.card_installments.first.month).to eq(original_month)
      expect(movable_transaction.card_installments.first.year).to eq(original_year)
    end
  end

  describe "[ #destroy ]" do
    before do
      (1..3).each do |i|
        sign_in user
        card_transaction.description = i
        post card_transactions_path, params: card_transaction.params, headers: turbo_stream_headers
      end
    end

    it "succeeds on request to #destroy" do
      card_transactions = CardTransaction.where(description: (1..3))

      card_transactions.each do |card_transaction_to_be_deleted|
        card_installment_id = card_transaction_to_be_deleted.card_installments.first.id

        sign_in user

        expect do
          delete card_transaction_path(card_transaction_to_be_deleted, card_installment_id:), headers: turbo_stream_headers
        end.to change(CardTransaction, :count).by(-1)
        expect(card_transaction_to_be_deleted.card_installments).to_not be_present
        expect(card_transaction_to_be_deleted.entity_transactions).to_not be_present
      end
    end

    it "returns unprocessable_entity when destroying a transaction with paid history" do
      locked_transaction = create_card_transaction_with_paid_history(description: "Locked destroy card")

      expect do
        delete card_transaction_path(locked_transaction, card_installment_id: locked_transaction.card_installments.first.id), headers: turbo_stream_headers
      end.not_to change(CardTransaction, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include(I18n.t("activerecord.errors.models.card_transaction.attributes.base.destroy_locked_after_payment"))
      expect(response.body).to include(I18n.t("notification.history_workarounds.destroy_locked_after_payment"))
      expect(locked_transaction.reload).to be_present
    end

    it "returns unprocessable_content when destroying a card advance with a locked linked cash transaction" do
      advanced_card_transaction = create_card_advance_transaction
      advance_cash_transaction = advanced_card_transaction.advance_cash_transaction

      expect do
        delete card_transaction_path(advanced_card_transaction, card_installment_id: advanced_card_transaction.card_installments.first.id),
               headers: turbo_stream_headers
      end.not_to change(CardTransaction, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include(I18n.t("activerecord.errors.models.card_transaction.attributes.base.destroy_locked_after_payment"))
      expect(response.body).to include(I18n.t("notification.history_workarounds.destroy_locked_after_payment"))
      expect(advanced_card_transaction.reload).to be_present
      expect(advance_cash_transaction.reload).to be_present
    end

    it "returns unprocessable_content when destroying a card transaction with a locked exchange projection" do
      locked_transaction = create_card_transaction_with_locked_exchange_projection
      exchange_cash_transaction = locked_transaction.entity_transactions.first.exchanges.first.cash_transaction

      expect do
        delete card_transaction_path(
          locked_transaction,
          card_installment_id: locked_transaction.card_installments.first.id
        ), headers: turbo_stream_headers
      end.not_to change(CardTransaction, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include(I18n.t("activerecord.errors.models.exchange.attributes.base.destroy_locked_after_payment"))
      expect(response.body).to include(I18n.t("notification.history_workarounds.destroy_locked_after_payment"))
      expect(locked_transaction.reload).to be_present
      expect(exchange_cash_transaction.reload).to be_present
    end
  end

  describe "[ #duplicate ]" do
    it "renders a duplicated transaction form without creating a new record" do
      post card_transactions_path, params: card_transaction.params, headers: turbo_stream_headers
      existing_card_transaction = CardTransaction.last

      expect { get duplicate_card_transaction_path(existing_card_transaction) }.not_to change(CardTransaction, :count)
      follow_redirect! if response.redirect?
      expect(response).to have_http_status(:success)
      expect(response.body).to include(existing_card_transaction.description)
    end
  end

  describe "[ context isolation ]" do
    it "keeps create, update, and destroy changes inside the derived context" do
      main_card_transaction = create(
        :card_transaction,
        user:,
        context: user.main_context,
        user_card: user_card_one,
        description: "Main isolated card transaction",
        price: -9_000,
        date: Date.new(2026, 4, 10),
        month: 5,
        year: 2026
      )
      main_card_transaction.category_transactions.destroy_all
      main_card_transaction.entity_transactions.destroy_all
      main_card_transaction.category_transactions.create!(category: exchange_category)
      main_card_transaction.entity_transactions.create!(
        entity: entity_one,
        is_payer: false,
        price: 0,
        price_to_be_returned: 0
      )

      derived_context = Logic::ContextCloneService.new(
        source_context: user.main_context,
        name: "Card Isolation"
      ).call
      derived_card_transaction = derived_context.card_transactions.find_by!(description: main_card_transaction.description)

      switch_to_context!(derived_context)

      create_params = Params::CardTransactions.new(
        card_transaction: {
          description: "Derived only card transaction",
          price: -11_000,
          date: Date.new(2026, 4, 12),
          month: 5,
          year: 2026,
          user_id: user.id,
          user_card_id: user_card_one.id
        },
        card_installments: { count: 1 },
        category_transactions: [ { category_id: exchange_category.id } ],
        entity_transactions: [ {
          entity_id: entity_one.id,
          price: 0,
          price_to_be_returned: 0,
          exchanges_attributes: []
        } ]
      )

      expect do
        post card_transactions_path, params: create_params.params, headers: turbo_stream_headers
      end.to change { derived_context.card_transactions.reload.count }.by(1)
                                                                      .and change { user.main_context.card_transactions.reload.count }.by(0)

      update_params = Params::CardTransactions.new
      update_params.use_base(derived_card_transaction, card_transaction_options: { description: "Derived updated card transaction", price: -12_500 })
      update_params.card_installments.each { |installment| installment[:price] = -12_500 }

      put card_transaction_path(derived_card_transaction), params: update_params.params, headers: turbo_stream_headers

      expect(derived_card_transaction.reload.description).to eq("Derived updated card transaction")
      expect(derived_card_transaction.price).to eq(-12_500)
      expect(main_card_transaction.reload.description).to eq("Main isolated card transaction")
      expect(main_card_transaction.price).to eq(-9_000)

      card_installment_id = derived_card_transaction.card_installments.first.id

      expect do
        delete card_transaction_path(derived_card_transaction, card_installment_id:), headers: turbo_stream_headers
      end.to change { derived_context.card_transactions.reload.count }.by(-1)
                                                                      .and change { user.main_context.card_transactions.reload.count }.by(0)

      expect(CardTransaction.exists?(main_card_transaction.id)).to be(true)
    end
  end

  describe "[ cross-context access denial ]" do
    it "does not allow editing, updating, or destroying a main-context card transaction while in a derived context" do
      main_card_transaction = create(
        :card_transaction,
        user:,
        context: user.main_context,
        user_card: user_card_one,
        description: "Main inaccessible card transaction",
        price: -9_000
      )

      derived_context = Logic::ContextCloneService.new(
        source_context: user.main_context,
        name: "Card Access Isolation"
      ).call

      switch_to_context!(derived_context)

      get edit_card_transaction_path(main_card_transaction)
      expect(response).to have_http_status(:not_found)

      patch card_transaction_path(main_card_transaction), params: {
        card_transaction: {
          description: "Should not update",
          price: main_card_transaction.price,
          date: main_card_transaction.date,
          month: main_card_transaction.month,
          year: main_card_transaction.year,
          user_id: user.id,
          user_card_id: user_card_one.id,
          card_installments_attributes: main_card_transaction.card_installments.map do |installment|
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

      delete card_transaction_path(main_card_transaction, card_installment_id: main_card_transaction.card_installments.first.id), headers: turbo_stream_headers
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "[ #pay_in_advance ]" do
    before do
      card_transaction.entity_transactions = [ { entity_id: entity_one.id, price: 0, price_to_be_returned: 0, exchanges_attributes: [] } ]
      card_transaction.price = -500
      post card_transactions_path, params: card_transaction.params, headers: turbo_stream_headers
    end

    it "creates a CARD ADVANCE transaction and its linked cash transaction" do
      expect do
        post pay_in_advance_card_transactions_path, params: {
          card_transaction: {
            user_card_id: user_card_one.id,
            date: Time.zone.today,
            month: Time.zone.today.month,
            year: Time.zone.today.year,
            price: 200
          }
        }, headers: turbo_stream_headers
      end.to change(CardTransaction, :count).by(1)

      advanced_card_transaction = CardTransaction.last

      expect(advanced_card_transaction.categories.pluck(:category_name)).to include("CARD ADVANCE")
      expect(advanced_card_transaction.price).to eq(200)
      expect(advanced_card_transaction.advance_cash_transaction).to be_present
      expect(advanced_card_transaction.advance_cash_transaction.price).to eq(-200)
    end

    it "keeps the card advance and linked cash transaction inside the derived context" do
      derived_context = Logic::ContextCloneService.new(
        source_context: user.main_context,
        name: "Card Advance Isolation"
      ).call

      switch_to_context!(derived_context)

      expect do
        post pay_in_advance_card_transactions_path, params: {
          card_transaction: {
            user_card_id: user_card_one.id,
            date: Time.zone.today,
            month: Time.zone.today.month,
            year: Time.zone.today.year,
            price: 200
          }
        }, headers: turbo_stream_headers
      end.to change { derived_context.card_transactions.reload.count }.by(1)
         .and change { derived_context.cash_transactions.reload.count }.by(1)

      expect(user.main_context.card_transactions.reload.count).to eq(1)
      expect(user.main_context.cash_transactions.reload.count).to eq(1)

      advanced_card_transaction = derived_context.card_transactions.order(:id).last

      expect(advanced_card_transaction.advance_cash_transaction).to be_present
      expect(advanced_card_transaction.context).to eq(derived_context)
      expect(advanced_card_transaction.advance_cash_transaction.context).to eq(derived_context)
    end
  end
end
