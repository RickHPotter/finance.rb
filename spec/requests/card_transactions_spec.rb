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

  describe "[ #new ]" do
    it "renders RubyUI comboboxes and split datetime input for user card, category, and entity selection" do
      user_card_one

      get new_card_transaction_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include('data-controller="form-loading"')
      expect(response.body).to include('id="card_transaction_form_submission_skeleton"')
      expect(response.body).to include('data-controller="ruby-ui--combobox"')
      expect(response.body).to include('data-controller="datetime-input"')
      expect(response.body).to include('data-controller="nested-form installment-lock installments-display"')
      expect(response.body).to include('data-controller="nested-form form-collection-carousel"')
      expect(response.body).to include('id="card_transaction_date"')
      expect(response.body).to include('id="card_transaction_date_time_input"')
      expect(response.body).not_to include("hw-combobox")
    end

    it "renders the card-specific form skeleton on edit" do
      user_card_one
      existing_card_transaction = create(
        :card_transaction,
        user:,
        context: user.main_context,
        user_card: user_card_one,
        description: "Existing card transaction",
        price: -12_345,
        date: Date.new(2026, 4, 2),
        month: 4,
        year: 2026
      )

      get edit_card_transaction_path(existing_card_transaction)

      expect(response).to have_http_status(:success)
      expect(response.body).to include('data-controller="form-loading"')
      expect(response.body).to include('id="card_transaction_form_submission_skeleton"')
      expect(response.body).to include('name="card_transaction[historical_correction_confirmation]"')
    end

    it "renders the bulk add to subscription action on the index" do
      user_card_one

      get card_transactions_path(user_card_id: user_card_one.id)

      expect(response).to have_http_status(:success)
      expect(response.body).to include(I18n.t("actions.add_to_subscription"))
    end

    it "uses canonical sort fields instead of the legacy order select on the index" do
      user_card_one

      get card_transactions_path(user_card_id: user_card_one.id)

      expect(response).to have_http_status(:success)
      expect(response.body).to include('name="sort"')
      expect(response.body).to include('name="direction"')
      expect(response.body).not_to include('name="order_by"')
      expect(response.body).to include('data-sort-field="description"')
      expect(response.body).to include('data-sort-field="installment_date"')
      expect(response.body).to include('data-sort-field="transaction_date"')
      expect(response.body).to include('data-sort-field="price"')
    end

    it "renders the mobile sort preset select" do
      user_card_one

      get card_transactions_path(user_card_id: user_card_one.id), headers: { "HTTP_USER_AGENT" => "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)" }

      expect(response).to have_http_status(:success)
      expect(response.body).to include('id="card_transactions_sort_preset"')
      expect(response.body).to include('data-action="change-&gt;datatable#applySortPreset"')

      document = Nokogiri::HTML.fragment(response.body)
      expect(document.at_css("form#search_form #card_transactions_sort_preset")).to be_present
    end

    it "keeps advanced filter range fields blank until the user fills them" do
      user_card_one

      get card_transactions_path(user_card_id: user_card_one.id)

      expect(response).to have_http_status(:success)
      expect(response.body).not_to match(/name="from_installments_count"[^>]*value="1"|value="1"[^>]*name="from_installments_count"/)
      expect(response.body).not_to match(/name="to_installments_count"[^>]*value="72"|value="72"[^>]*name="to_installments_count"/)
      expect(response.body).to include("price-mask#toggleSign")
      expect(response.body).to include('data-sign="+"')
      expect(response.body).to include("price-range-from-ct-price")
      expect(response.body).to include("price-range-to-price")
    end

    it "keeps the exchange bound type filter selected when filtering exchange rows" do
      user_card_one

      get card_transactions_path(
        user_card_id: user_card_one.id,
        exchange_bound_type: "card_bound",
        card_transaction: { category_id: [ exchange_category.id ] }
      )

      expect(response).to have_http_status(:success)
      expect(response.body).to include(I18n.t("filters.summary.items.exchange_bound_type", value: I18n.t("filters.exchange_bound_type.card_bound")))
      expect(response.body).to include('name="exchange_bound_type"')
      expect(response.body).to include('id="exchange_bound_type"')
      expect(response.body).to include('form="search_form"')
      expect(response.body).to include('data-controller="request-submit"')
      expect(response.body).to include('data-request-submit-form-id-value="search_form"')
    end

    it "renders a filter summary with a reset link that keeps the explicit card scope" do
      user_card_one
      category = create(:category, user:, category_name: "FOOD")

      get card_transactions_path(
        user_card_id: user_card_one.id,
        search_term: "market",
        from_installments_count: 1,
        to_installments_count: 68,
        card_transaction: { category_id: [ category.id ] }
      )

      expect(response).to have_http_status(:success)
      expect(response.body).to include(I18n.t("filters.summary.active"))
      expect(response.body).to include(I18n.t("filters.summary.clear"))
      expect(response.body).to include("user_card_id=#{user_card_one.id}")

      document = Nokogiri::HTML.fragment(response.body)
      chips = document.css("a[aria-label^=\"#{I18n.t('filters.summary.clear')}\"]")
      search_chip = chips.find { |chip| chip.text.include?(I18n.t("filters.summary.items.search_term", value: "market")) }
      category_chip = chips.find { |chip| chip.text.include?(I18n.t("filters.summary.items.categories", count: 1)) }
      installments_chip = chips.find { |chip| chip.text.include?(I18n.t("filters.summary.items.installments_count", value: "1 -> 68")) }

      expect(search_chip).to be_present
      expect(search_chip["href"]).to include("user_card_id=#{user_card_one.id}")
      expect(search_chip["href"]).not_to include("search_term=")
      expect(search_chip["title"]).to eq(I18n.t("filters.summary.items.search_term", value: "market"))
      expect(search_chip.text).to end_with("x")

      expect(category_chip).to be_present
      expect(category_chip["href"]).to include("search_term=market")
      expect(category_chip["href"]).not_to include("category_id")

      expect(installments_chip).to be_present
      expect(installments_chip["href"]).not_to include("from_installments_count")
      expect(installments_chip["href"]).not_to include("to_installments_count")
    end
  end

  describe "[ #add_to_subscription ]" do
    it "adds the selected card transactions to the chosen subscription" do
      other_subscription = create(:subscription, user:, description: "Recurring card bundle")
      first_transaction = create(
        :card_transaction,
        user:,
        context: user.main_context,
        user_card: user_card_one,
        description: "Streaming service",
        price: -6_500,
        date: Date.new(2026, 4, 3),
        month: 4,
        year: 2026
      )
      second_transaction = create(
        :card_transaction,
        user:,
        context: user.main_context,
        user_card: user_card_two,
        description: "Cloud storage",
        price: -3_200,
        date: Date.new(2026, 4, 4),
        month: 4,
        year: 2026
      )

      post add_to_subscription_card_transactions_path,
           params: {
             ids: [ first_transaction.id, second_transaction.id ].join(","),
             subscription_id: other_subscription.id,
             index_context_json: {}.to_json
           },
           headers: turbo_stream_headers

      expect(response).to have_http_status(:success)
      expect(first_transaction.reload.subscription).to eq(other_subscription)
      expect(second_transaction.reload.subscription).to eq(other_subscription)
      expect(response.body).to include(I18n.t("notification.added_to_subscription"))
    end
  end

  def switch_to_context!(context)
    patch switch_context_path(context)
    expect(response).to redirect_to(root_path)
  end

  def create_card_transaction_with_history(description: "Locked card transaction", installments: nil) # rubocop:disable Metrics/AbcSize
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
    installments ||= [
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

  def create_card_transaction_with_paid_history(description: "Locked card transaction")
    create_card_transaction_with_history(description:)
  end

  def create_supporting_card_transaction(invoice_cash_transaction:) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
    transaction = create(
      :card_transaction,
      user:,
      context: user.main_context,
      user_card: user_card_one,
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
    it "continues a create chain with the created ids tracked in the next form" do
      expect do
        post card_transactions_path,
             params: card_transaction.params.merge(chain_mode: "create", continue_chain: "1"),
             headers: turbo_stream_headers
      end.to change(CardTransaction, :count).by(1)

      created_card_transaction = CardTransaction.last

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Chain Creating")
      expect(response.body).to match(/name="chain_mode"[^>]*value="create"/)
      expect(response.body).to match(/name="chain_record_ids\[\]"[^>]*value="#{created_card_transaction.id}"/)
      expect(response.body).to include('name="continue_chain" value="1"')
      expect(response.body).to include("checked")
    end

    it "shows generic and detailed failure notifications when create validation fails" do
      expect do
        post card_transactions_path,
             params: card_transaction.params.deep_merge(card_transaction: { description: "" }),
             headers: turbo_stream_headers
      end.not_to change(CardTransaction, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include(I18n.t("notification.not_createda", model: CardTransaction.model_name.human))
      expect(response.body).to include(CardTransaction.human_attribute_name(:description))
      expect(response.body).to include("can&#39;t be blank")
      expect(response.body).not_to include(">is invalid<")
      expect(response.body).to include('<turbo-stream action="update" target="notification">')
      expect(response.body).to include('<turbo-stream action="append" target="notification">')
    end

    it "finishes a chain without saving the current card transaction form" do
      existing_card_transaction = create(
        :card_transaction,
        user:,
        context: user.main_context,
        user_card: user_card_one,
        description: "Existing chained card transaction",
        price: -12_345,
        date: Date.new(2026, 4, 3),
        month: 4,
        year: 2026
      )

      expect do
        post card_transactions_path,
             params: {
               chain_mode: "create",
               chain_record_ids: [ existing_card_transaction.id ],
               finish_chain_without_save: "1",
               card_transaction: {
                 description: "",
                 price: "",
                 date: "",
                 user_id: user.id,
                 user_card_id: user_card_one.id
               }
             },
             headers: turbo_stream_headers
      end.not_to change(CardTransaction, :count)

      expected_month_year = format("%<year>04d%<month>02d", year: existing_card_transaction.card_installments.first.year,
                                                            month: existing_card_transaction.card_installments.first.month)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("month_year_container_#{expected_month_year}")
      expect(response.body).to include("/card_transactions?user_card_id=#{user_card_one.id}")
      expect(response.body).not_to include("Chain Creating")
    end

    it "keeps duplicate chain controls checked on hidden update submits" do
      post card_transactions_path, params: {
        chain_mode: "duplicate",
        continue_chain: "1",
        commit: "Update",
        card_transaction: {
          duplicate: "true",
          description: "Duplicate preview",
          date: Time.zone.today,
          month: Time.zone.today.month,
          year: Time.zone.today.year,
          price: -1000,
          user_id: user.id,
          user_card_id: user_card_one.id,
          card_installments_attributes: [
            { number: 1, date: Time.zone.today, month: Time.zone.today.month, year: Time.zone.today.year, price: -1000 }
          ],
          category_transactions_attributes: [
            { category_id: exchange_category.id }
          ],
          entity_transactions_attributes: [
            { entity_id: entity_one.id, price: 0, price_to_be_returned: 0, exchanges_attributes: [] }
          ]
        }
      }, headers: turbo_stream_headers

      expect(response).to have_http_status(:success)
      expect(response.body).to match(/name="chain_mode"[^>]*value="duplicate"/)
      expect(response.body).to include('name="continue_chain" value="1"')
      expect(response.body).to include("checked")
    end

    it "deduplicates repeated categories and entities when saving a duplicate chain round" do
      extra_category = create(:category, :random, user:)
      extra_entity = create(:entity, :random, user:)

      expect do
        post card_transactions_path, params: {
          chain_mode: "duplicate",
          continue_chain: "1",
          card_transaction: {
            description: "Duplicated card transaction",
            price: -20_000,
            date: Time.zone.today,
            month: Time.zone.today.month,
            year: Time.zone.today.year,
            user_id: user.id,
            user_card_id: user_card_one.id,
            card_installments_attributes: [
              { number: 1, date: Time.zone.today, month: Time.zone.today.month, year: Time.zone.today.year, price: -20_000 }
            ],
            category_transactions_attributes: [
              { category_id: exchange_category.id },
              { category_id: exchange_category.id },
              { category_id: extra_category.id }
            ],
            entity_transactions_attributes: [
              { entity_id: entity_one.id, price: 0, price_to_be_returned: 0, exchanges_attributes: [] },
              { entity_id: entity_one.id, price: 0, price_to_be_returned: 0, exchanges_attributes: [] },
              { entity_id: extra_entity.id, price: 0, price_to_be_returned: 0, exchanges_attributes: [] }
            ]
          }
        }, headers: turbo_stream_headers
      end.to change(CardTransaction, :count).by(1)

      created_card_transaction = CardTransaction.last

      expect(response).to have_http_status(:success)
      expect(created_card_transaction.categories).to contain_exactly(exchange_category, extra_category)
      expect(created_card_transaction.entities).to contain_exactly(entity_one, extra_entity)
    end

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
      expect(shared_exchange_return.reference_transactable).to be_nil
      expect(shared_exchange_return.cash_installments.order(:number).pluck(:price)).to eq([ -5099 ])
      expect(shared_exchange_return.exchanges.card_bound.order(:number, :date).pluck(:price)).to eq([ -2200, -2899 ])
    end

    it "preserves the paid partial installment and increases the unpaid card-bound EXCHANGE RETURN remainder in the same bucket" do
      create(:reference, context: user.main_context, user_card: user_card_one, month: 4, year: 2026, reference_date: Date.new(2026, 4, 12))

      first_params = Params::CardTransactions.new(
        card_transaction: {
          price: -2_200,
          date: Time.zone.local(2026, 3, 20, 10, 0, 0),
          month: 4,
          year: 2026,
          user_id: user.id,
          user_card_id: user_card_one.id
        },
        card_installments: { count: 1 },
        category_transactions: [ { category_id: exchange_category.id } ],
        entity_transactions: [ {
          entity_id: entity_one.id,
          price: -2_200,
          price_to_be_returned: -2_200,
          exchanges_attributes: [ { price: -2_200, exchange_type: :monetary, date: Time.zone.local(2026, 3, 20, 10, 0, 0), month: 4, year: 2026 } ]
        } ]
      )

      post card_transactions_path, params: first_params.params, headers: turbo_stream_headers

      shared_exchange_return = CardTransaction.last.entity_transactions.first.exchanges.first.cash_transaction.reload

      patch pay_cash_installment_path(shared_exchange_return.cash_installments.find_by!(number: 1)), params: {
        cash_installment: {
          date: Time.zone.local(2026, 3, 26, 17, 0, 0).strftime("%Y-%m-%dT%H:%M"),
          price: -500
        }
      }, headers: turbo_stream_headers

      expect(shared_exchange_return.reload.cash_installments.order(:number).pluck(:price, :paid)).to eq([ [ -500, true ], [ -1700, false ] ])

      sign_in user

      second_params = Params::CardTransactions.new(
        card_transaction: {
          price: -2_899,
          date: Time.zone.local(2026, 3, 21, 10, 0, 0),
          month: 4,
          year: 2026,
          user_id: user.id,
          user_card_id: user_card_one.id
        },
        card_installments: { count: 1 },
        category_transactions: [ { category_id: exchange_category.id } ],
        entity_transactions: [ {
          entity_id: entity_one.id,
          price: -2_899,
          price_to_be_returned: -2_899,
          exchanges_attributes: [ { price: -2_899, exchange_type: :monetary, date: Time.zone.local(2026, 3, 21, 10, 0, 0), month: 4, year: 2026 } ]
        } ]
      )

      expect { post card_transactions_path, params: second_params.params, headers: turbo_stream_headers }.to change(CardTransaction, :count).by(1)

      shared_exchange_return.reload

      expect(CardTransaction.last.entity_transactions.first.exchanges.first.cash_transaction_id).to eq(shared_exchange_return.id)
      expect(shared_exchange_return.cash_installments.order(:number).pluck(:price, :paid)).to eq([ [ -500, true ], [ -4599, false ] ])
      expected_due_date = Time.zone.local(2026, 4, 12).end_of_day.change(usec: 999_999)

      expect(shared_exchange_return.cash_installments.order(:number).pluck(:date)).to eq(
        [ Time.zone.local(2026, 3, 26, 17, 0, 0), expected_due_date ]
      )
      expect(shared_exchange_return.date).to eq(expected_due_date)
      expect(shared_exchange_return.month).to eq(4)
      expect(shared_exchange_return.year).to eq(2026)
    end

    it "adds only the latest same-bucket exchange amount to the unpaid remainder after a partial pay" do
      create(:reference, context: user.main_context, user_card: user_card_one, month: 4, year: 2026, reference_date: Date.new(2026, 4, 12))

      first_params = Params::CardTransactions.new(
        card_transaction: {
          price: -2_200,
          date: Time.zone.local(2026, 3, 20, 10, 0, 0),
          month: 4,
          year: 2026,
          user_id: user.id,
          user_card_id: user_card_one.id
        },
        card_installments: { count: 1 },
        category_transactions: [ { category_id: exchange_category.id } ],
        entity_transactions: [ {
          entity_id: entity_one.id,
          price: -2_200,
          price_to_be_returned: -2_200,
          exchanges_attributes: [ { price: -2_200, exchange_type: :monetary, date: Time.zone.local(2026, 3, 20, 10, 0, 0), month: 4, year: 2026 } ]
        } ]
      )
      second_params = Params::CardTransactions.new(
        card_transaction: {
          price: -2_899,
          date: Time.zone.local(2026, 3, 21, 10, 0, 0),
          month: 4,
          year: 2026,
          user_id: user.id,
          user_card_id: user_card_one.id
        },
        card_installments: { count: 1 },
        category_transactions: [ { category_id: exchange_category.id } ],
        entity_transactions: [ {
          entity_id: entity_one.id,
          price: -2_899,
          price_to_be_returned: -2_899,
          exchanges_attributes: [ { price: -2_899, exchange_type: :monetary, date: Time.zone.local(2026, 3, 21, 10, 0, 0), month: 4, year: 2026 } ]
        } ]
      )

      post card_transactions_path, params: first_params.params, headers: turbo_stream_headers
      first_card_transaction = CardTransaction.last

      sign_in user

      post card_transactions_path, params: second_params.params, headers: turbo_stream_headers
      second_card_transaction = CardTransaction.last

      shared_exchange_return = first_card_transaction.entity_transactions.first.exchanges.first.cash_transaction.reload

      expect(second_card_transaction.entity_transactions.first.exchanges.first.cash_transaction_id).to eq(shared_exchange_return.id)
      expect(shared_exchange_return.cash_installments.order(:number).pluck(:price, :paid)).to eq([ [ -5_099, false ] ])

      patch pay_cash_installment_path(shared_exchange_return.cash_installments.find_by!(number: 1)), params: {
        cash_installment: {
          date: Time.zone.local(2026, 3, 26, 17, 0, 0).strftime("%Y-%m-%dT%H:%M"),
          price: -500
        }
      }, headers: turbo_stream_headers

      expect(shared_exchange_return.reload.cash_installments.order(:number).pluck(:price, :paid)).to eq([ [ -500, true ], [ -4_599, false ] ])

      sign_in user

      third_params = Params::CardTransactions.new(
        card_transaction: {
          price: -1_300,
          date: Time.zone.local(2026, 3, 22, 10, 0, 0),
          month: 4,
          year: 2026,
          user_id: user.id,
          user_card_id: user_card_one.id
        },
        card_installments: { count: 1 },
        category_transactions: [ { category_id: exchange_category.id } ],
        entity_transactions: [ {
          entity_id: entity_one.id,
          price: -1_300,
          price_to_be_returned: -1_300,
          exchanges_attributes: [ { price: -1_300, exchange_type: :monetary, date: Time.zone.local(2026, 3, 22, 10, 0, 0), month: 4, year: 2026 } ]
        } ]
      )

      post card_transactions_path, params: third_params.params, headers: turbo_stream_headers

      shared_exchange_return.reload
      paid_installment, unpaid_installment = shared_exchange_return.cash_installments.order(:number)

      expect(CardTransaction.last.entity_transactions.first.exchanges.first.cash_transaction_id).to eq(shared_exchange_return.id)
      expect(shared_exchange_return.cash_installments_count).to eq(2)
      expect(shared_exchange_return.price).to eq(-6_399)
      expect(paid_installment.price).to eq(-500)
      expect(paid_installment).to be_paid
      expect(unpaid_installment.price).to eq(-5_899)
      expect(unpaid_installment).not_to be_paid
      expect(unpaid_installment.price).not_to eq(shared_exchange_return.price)

      sign_in user

      fourth_params = Params::CardTransactions.new(
        card_transaction: {
          price: -700,
          date: Time.zone.local(2026, 3, 23, 10, 0, 0),
          month: 4,
          year: 2026,
          user_id: user.id,
          user_card_id: user_card_one.id
        },
        card_installments: { count: 1 },
        category_transactions: [ { category_id: exchange_category.id } ],
        entity_transactions: [ {
          entity_id: entity_one.id,
          price: -700,
          price_to_be_returned: -700,
          exchanges_attributes: [ { price: -700, exchange_type: :monetary, date: Time.zone.local(2026, 3, 23, 10, 0, 0), month: 4, year: 2026 } ]
        } ]
      )

      post card_transactions_path, params: fourth_params.params, headers: turbo_stream_headers

      shared_exchange_return.reload
      paid_installment, unpaid_installment = shared_exchange_return.cash_installments.order(:number)

      expect(CardTransaction.last.entity_transactions.first.exchanges.first.cash_transaction_id).to eq(shared_exchange_return.id)
      expect(shared_exchange_return.price).to eq(-7_099)
      expect(paid_installment.price).to eq(-500)
      expect(paid_installment).to be_paid
      expect(unpaid_installment.price).to eq(-6_599)
      expect(unpaid_installment).not_to be_paid

      patch pay_cash_installment_path(unpaid_installment), params: {
        cash_installment: {
          date: Time.zone.local(2026, 3, 27, 17, 0, 0).strftime("%Y-%m-%dT%H:%M"),
          price: -1_000
        }
      }, headers: turbo_stream_headers

      shared_exchange_return.reload
      first_paid, second_paid, third_unpaid = shared_exchange_return.cash_installments.order(:number)

      expect(shared_exchange_return.cash_installments.order(:number).pluck(:price, :paid)).to eq([ [ -500, true ], [ -1_000, true ], [ -5_599, false ] ])
      expect(first_paid.date).to eq(Time.zone.local(2026, 3, 26, 17, 0, 0))
      expect(second_paid.date).to eq(Time.zone.local(2026, 3, 27, 17, 0, 0))
      expect(third_unpaid).not_to be_paid

      sign_in user

      fifth_params = Params::CardTransactions.new(
        card_transaction: {
          price: -900,
          date: Time.zone.local(2026, 3, 24, 10, 0, 0),
          month: 4,
          year: 2026,
          user_id: user.id,
          user_card_id: user_card_one.id
        },
        card_installments: { count: 1 },
        category_transactions: [ { category_id: exchange_category.id } ],
        entity_transactions: [ {
          entity_id: entity_one.id,
          price: -900,
          price_to_be_returned: -900,
          exchanges_attributes: [ { price: -900, exchange_type: :monetary, date: Time.zone.local(2026, 3, 24, 10, 0, 0), month: 4, year: 2026 } ]
        } ]
      )

      post card_transactions_path, params: fifth_params.params, headers: turbo_stream_headers

      shared_exchange_return.reload
      first_paid, second_paid, third_unpaid = shared_exchange_return.cash_installments.order(:number)

      expect(CardTransaction.last.entity_transactions.first.exchanges.first.cash_transaction_id).to eq(shared_exchange_return.id)
      expect(shared_exchange_return.cash_installments_count).to eq(3)
      expect(shared_exchange_return.price).to eq(-7_999)
      expect(first_paid.price).to eq(-500)
      expect(first_paid).to be_paid
      expect(second_paid.price).to eq(-1_000)
      expect(second_paid).to be_paid
      expect(third_unpaid.price).to eq(-6_499)
      expect(third_unpaid).not_to be_paid
      expect(third_unpaid.price).not_to eq(shared_exchange_return.price)
    end

    it "prefers the active unpaid shared return over older paid card-bound candidates after multiple partial pays" do
      due_date = Time.zone.local(2026, 4, 12).end_of_day.change(usec: 999_999)
      create(:reference, context: user.main_context, user_card: user_card_one, month: 4, year: 2026, reference_date: Date.new(2026, 4, 12))

      stale_shared_return = CashTransaction.create!(
        user:,
        context: user.main_context,
        user_card: user_card_one,
        description: "[ 04/2026 ] #{entity_one.entity_name} - #{user_card_one.user_card_name}",
        date: due_date,
        month: 4,
        year: 2026,
        price: -1_200,
        cash_transaction_type: "Exchange",
        category_transactions_attributes: [
          { category_id: user.built_in_category("EXCHANGE RETURN").id }
        ],
        entity_transactions_attributes: [
          { entity_id: entity_one.id, is_payer: false, price: 0, price_to_be_returned: 0 }
        ],
        cash_installments_attributes: [
          { number: 1, date: due_date, month: 4, year: 2026, price: -1_200, paid: true }
        ]
      )
      stale_shared_return.cash_installments.destroy_all
      stale_shared_return.cash_installments.create!(number: 1, date: due_date, month: 4, year: 2026, price: -1_200, paid: true)
      stale_shared_return.update_columns(cash_installments_count: 1, paid: true)

      stale_origin = create(
        :card_transaction,
        user:,
        context: user.main_context,
        user_card: user_card_one,
        description: "Stale card-bound source",
        date: Time.zone.local(2025, 12, 20, 10, 0, 0),
        month: 4,
        year: 2026,
        price: -1_200
      )
      stale_origin.category_transactions.destroy_all
      stale_origin.category_transactions.create!(category: exchange_category)
      stale_entity_transaction = stale_origin.entity_transactions.first
      stale_entity_transaction.update!(entity_id: entity_one.id, is_payer: true, price: -1_200, price_to_be_returned: -1_200, exchanges_count: 1)
      now = Time.current
      Exchange.insert_all!([
                             {
                               entity_transaction_id: stale_entity_transaction.id,
                               cash_transaction_id: stale_shared_return.id,
                               bound_type: Exchange.bound_types[:card_bound],
                               exchange_type: Exchange.exchange_types[:monetary],
                               number: 1,
                               price: -1_200,
                               starting_price: -1_200,
                               date: due_date,
                               month: 4,
                               year: 2026,
                               created_at: now,
                               updated_at: now
                             }
                           ])

      shared_exchange_return = CashTransaction.create!(
        user:,
        context: user.main_context,
        user_card: user_card_one,
        description: "[ 04/2026 ] #{entity_one.entity_name} - #{user_card_one.user_card_name}",
        date: due_date,
        month: 4,
        year: 2026,
        price: -7_099,
        cash_transaction_type: "Exchange",
        category_transactions_attributes: [
          { category_id: user.built_in_category("EXCHANGE RETURN").id }
        ],
        entity_transactions_attributes: [
          { entity_id: entity_one.id, is_payer: false, price: 0, price_to_be_returned: 0 }
        ],
        cash_installments_attributes: [
          { number: 1, date: Time.zone.local(2026, 3, 26, 17, 0, 0), month: 3, year: 2026, price: -500, paid: true },
          { number: 2, date: Time.zone.local(2026, 3, 27, 17, 0, 0), month: 3, year: 2026, price: -1_000, paid: true },
          { number: 3, date: due_date, month: 4, year: 2026, price: -5_599, paid: false }
        ]
      )
      shared_exchange_return.cash_installments.destroy_all
      shared_exchange_return.cash_installments.create!(number: 1, date: Time.zone.local(2026, 3, 26, 17, 0, 0), month: 3, year: 2026, price: -500, paid: true)
      shared_exchange_return.cash_installments.create!(number: 2, date: Time.zone.local(2026, 3, 27, 17, 0, 0), month: 3, year: 2026, price: -1_000, paid: true)
      shared_exchange_return.cash_installments.create!(number: 3, date: due_date, month: 4, year: 2026, price: -5_599, paid: false)
      shared_exchange_return.update_columns(cash_installments_count: 3, paid: false)

      active_origin = create(
        :card_transaction,
        user:,
        context: user.main_context,
        user_card: user_card_one,
        description: "Active card-bound source",
        date: Time.zone.local(2026, 3, 24, 10, 0, 0),
        month: 4,
        year: 2026,
        price: -7_099
      )
      active_origin.category_transactions.destroy_all
      active_origin.category_transactions.create!(category: exchange_category)
      active_entity_transaction = active_origin.entity_transactions.first
      active_entity_transaction.update!(entity_id: entity_one.id, is_payer: true, price: -7_099, price_to_be_returned: -7_099, exchanges_count: 3)
      Exchange.insert_all!([
                             {
                               entity_transaction_id: active_entity_transaction.id,
                               cash_transaction_id: shared_exchange_return.id,
                               bound_type: Exchange.bound_types[:card_bound],
                               exchange_type: Exchange.exchange_types[:monetary],
                               number: 1,
                               price: -500,
                               starting_price: -500,
                               date: Time.zone.local(2026, 3, 26, 17, 0, 0),
                               month: 3,
                               year: 2026,
                               created_at: now,
                               updated_at: now
                             },
                             {
                               entity_transaction_id: active_entity_transaction.id,
                               cash_transaction_id: shared_exchange_return.id,
                               bound_type: Exchange.bound_types[:card_bound],
                               exchange_type: Exchange.exchange_types[:monetary],
                               number: 2,
                               price: -1_000,
                               starting_price: -1_000,
                               date: Time.zone.local(2026, 3, 27, 17, 0, 0),
                               month: 3,
                               year: 2026,
                               created_at: now,
                               updated_at: now
                             },
                             {
                               entity_transaction_id: active_entity_transaction.id,
                               cash_transaction_id: shared_exchange_return.id,
                               bound_type: Exchange.bound_types[:card_bound],
                               exchange_type: Exchange.exchange_types[:monetary],
                               number: 3,
                               price: -5_599,
                               starting_price: -5_599,
                               date: due_date,
                               month: 4,
                               year: 2026,
                               created_at: now,
                               updated_at: now
                             }
                           ])

      new_params = Params::CardTransactions.new(
        card_transaction: {
          price: -900,
          date: Time.zone.local(2026, 3, 24, 10, 0, 0),
          month: 4,
          year: 2026,
          user_id: user.id,
          user_card_id: user_card_one.id
        },
        card_installments: { count: 1 },
        category_transactions: [ { category_id: exchange_category.id } ],
        entity_transactions: [ {
          entity_id: entity_one.id,
          price: -900,
          price_to_be_returned: -900,
          exchanges_attributes: [ { price: -900, exchange_type: :monetary, date: Time.zone.local(2026, 3, 24, 10, 0, 0), month: 4, year: 2026 } ]
        } ]
      )

      post card_transactions_path, params: new_params.params, headers: turbo_stream_headers

      shared_exchange_return.reload
      stale_shared_return.reload
      first_paid, second_paid, third_unpaid = shared_exchange_return.cash_installments.order(:number)

      expect(CardTransaction.last.entity_transactions.first.exchanges.first.cash_transaction_id).to eq(shared_exchange_return.id)
      expect(shared_exchange_return.cash_installments_count).to eq(3)
      expect(shared_exchange_return.price).to eq(-7_999)
      expect(first_paid.price).to eq(-500)
      expect(first_paid).to be_paid
      expect(second_paid.price).to eq(-1_000)
      expect(second_paid).to be_paid
      expect(third_unpaid.price).to eq(-6_499)
      expect(third_unpaid).not_to be_paid
      expect(stale_shared_return.cash_installments.order(:number).pluck(:price, :paid)).to eq([ [ -1_200, true ] ])
    end

    it "uses different card-bound EXCHANGE RETURN cash transactions when two exchanges belong to different months" do
      current_date = Time.zone.local(2026, 3, 20, 10, 0, 0)
      card_transaction.date = current_date
      card_transaction.month = 4
      card_transaction.year = 2026
      card_transaction.card_installments = { count: 2 }
      card_transaction.category_transactions = [ { category_id: exchange_category.id } ]
      card_transaction.entity_transactions = [
        {
          entity_id: entity_one.id,
          price: -12_000,
          price_to_be_returned: -12_000,
          exchanges_attributes: [
            { price: -6_000, exchange_type: :monetary, date: Time.zone.local(2026, 4, 24), month: 4, year: 2026 },
            { price: -6_000, exchange_type: :monetary, date: Time.zone.local(2026, 5, 24), month: 5, year: 2026 }
          ]
        }
      ]

      expect { post card_transactions_path, params: card_transaction.params, headers: turbo_stream_headers }.to change(CardTransaction, :count).by(1)

      created_card_transaction = CardTransaction.last
      first_exchange, second_exchange = created_card_transaction.entity_transactions.first.exchanges.order(:number, :date)

      expect(first_exchange.cash_transaction_id).not_to eq(second_exchange.cash_transaction_id)

      april_return = CashTransaction.find(first_exchange.cash_transaction_id)
      may_return = CashTransaction.find(second_exchange.cash_transaction_id)

      expect(april_return.description).to eq("[ 04/2026 ] #{entity_one.entity_name} - #{user_card_one.user_card_name}")
      expect(april_return.cash_installments.order(:number).pluck(:price)).to eq([ -6_000 ])
      expect(may_return.description).to eq("[ 05/2026 ] #{entity_one.entity_name} - #{user_card_one.user_card_name}")
      expect(may_return.cash_installments.order(:number).pluck(:price)).to eq([ -6_000 ])
    end

    it "creates a past-dated EXCHANGE card transaction with an unpaid card-bound exchange return in the same bucket" do
      card_transaction.date = Time.zone.local(2026, 3, 15, 10, 0, 0)
      card_transaction.month = 4
      card_transaction.year = 2026
      card_transaction.card_installments = { count: 2 }
      card_transaction.category_transactions = [ { category_id: exchange_category.id } ]
      card_transaction.entity_transactions = [
        {
          entity_id: entity_one.id,
          price: -12_000,
          price_to_be_returned: -12_000,
          exchanges_attributes: [
            { price: -6_000, exchange_type: :monetary, date: Time.zone.local(2026, 3, 16, 10, 0, 0), month: 3, year: 2026 },
            { price: -6_000, exchange_type: :monetary, date: Time.zone.local(2026, 3, 20, 10, 0, 0), month: 3, year: 2026 }
          ]
        }
      ]

      expect { post card_transactions_path, params: card_transaction.params, headers: turbo_stream_headers }.to change(CardTransaction, :count).by(1)

      created_card_transaction = CardTransaction.last
      exchange_return = created_card_transaction.entity_transactions.first.exchanges.first.cash_transaction

      expect(exchange_return.cash_installments.order(:number).pluck(:price)).to eq([ -12_000 ])
      expect(exchange_return.cash_installments.order(:number).pluck(:paid)).to eq([ false ])
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

    it "shows generic and detailed failure notifications when update validation fails" do
      card_transaction.use_base(@existing_card_transaction, card_transaction_options: { description: "" })

      put(card_transaction_path(@existing_card_transaction), params: card_transaction.params, headers: turbo_stream_headers)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include(I18n.t("notification.not_updateda", model: CardTransaction.model_name.human))
      expect(response.body).to include(CardTransaction.human_attribute_name(:description))
      expect(response.body).to include("can&#39;t be blank")
      expect(response.body).not_to include(">is invalid<")
      expect(response.body).to include('<turbo-stream action="update" target="notification">')
      expect(response.body).to include('<turbo-stream action="append" target="notification">')
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

    it "shows a confirmation path and then allows a normal paid amount correction" do
      locked_transaction = create_card_transaction_with_paid_history(description: "Amount correction request")
      first_installment = locked_transaction.card_installments.find_by!(number: 1)
      second_installment = locked_transaction.card_installments.find_by!(number: 2)
      third_installment = locked_transaction.card_installments.find_by!(number: 3)

      base_params = {
        card_transaction: {
          description: locked_transaction.description,
          price: -3500,
          date: locked_transaction.date,
          month: locked_transaction.month,
          year: locked_transaction.year,
          user_id: user.id,
          user_card_id: user_card_one.id,
          category_transactions_attributes: locked_transaction.category_transactions.map { |ct| { id: ct.id, category_id: ct.category_id } },
          entity_transactions_attributes: [],
          card_installments_attributes: [
            { id: first_installment.id, number: 1, date: first_installment.date, month: first_installment.month, year: first_installment.year, price: -1500,
              paid: true },
            { id: second_installment.id, number: 2, date: second_installment.date, month: second_installment.month, year: second_installment.year, price: -1000,
              paid: false },
            { id: third_installment.id, number: 3, date: third_installment.date, month: third_installment.month, year: third_installment.year, price: -1000,
              paid: false }
          ]
        }
      }

      put card_transaction_path(locked_transaction), params: base_params, headers: turbo_stream_headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include(I18n.t("activerecord.errors.models.card_transaction.attributes.base.paid_amount_correction_confirmation_required"))
      expect(response.body).to include(I18n.t("actions.confirm_historical_change"))

      base_params[:card_transaction][:historical_correction_confirmation] = true

      put card_transaction_path(locked_transaction), params: base_params, headers: turbo_stream_headers

      expect(response).to have_http_status(:ok)
      expect(locked_transaction.reload.price).to eq(-3500)
      expect(locked_transaction.card_installments.order(:number).pluck(:price)).to eq([ -1500, -1000, -1000 ])
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
      expect(response.body).to include(I18n.t("notification.history_workarounds.paid_history_locked.card_transaction"))
      expect(exchange.reload.price).to eq(-2_200)
      expect(exchange.cash_transaction.reload.price).to eq(-2_200)
    end

    it "returns unprocessable_content when moving an unpaid card transaction into a paid invoice cycle" do
      movable_transaction, paid_invoice = create_card_transaction_with_paid_invoice_target
      original_cash_transaction = movable_transaction.card_installments.first.cash_transaction
      original_paid_invoice_price = paid_invoice.price
      original_paid_invoice_installment_price = paid_invoice.cash_installments.first.price
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
      expect(paid_invoice.reload.price).to eq(original_paid_invoice_price)
      expect(paid_invoice.cash_installments.first.reload.price).to eq(original_paid_invoice_installment_price)
      expect(movable_transaction.reload.card_installments.first.cash_transaction).to eq(original_cash_transaction)
      expect(movable_transaction.card_installments.first.month).to eq(original_month)
      expect(movable_transaction.card_installments.first.year).to eq(original_year)
    end

    it "allows changing a future unpaid installment amount when its date resolves to an older paid invoice cycle" do
      user_card_one.update!(due_date_day: 14, days_until_due_date: 7)
      transaction = create_card_transaction_with_history(
        description: "Future amount correction",
        installments: [
          { number: 1, price: -1000, date: Time.zone.local(2026, 2, 14, 12), month: 4, year: 2026, paid: true },
          { number: 2, price: -1000, date: Time.zone.local(2026, 3, 14, 12), month: 5, year: 2026, paid: false },
          { number: 3, price: -1000, date: Time.zone.local(2026, 4, 14, 12), month: 6, year: 2026, paid: false }
        ]
      )
      paid_invoice = transaction.card_installments.find_by!(number: 1).cash_transaction
      future_installment = transaction.card_installments.find_by!(number: 2)
      future_invoice = future_installment.cash_transaction
      future_invoice.cash_installments.update_all(paid: false)
      future_invoice.update_column(:paid, false)
      params = Params::CardTransactions.new
      params.use_base(transaction, card_transaction_options: { price: -3003 })
      params.card_installments.detect { |installment| installment[:id] == future_installment.id }[:price] = -1003

      put card_transaction_path(transaction), params: params.params, headers: turbo_stream_headers

      expect(response).to have_http_status(:ok)
      expect(future_installment.reload.price).to eq(-1003)
      expect(future_installment.cash_transaction).to eq(future_invoice)
      expect(future_invoice.reload.paid_history?).to be(false)
      expect(paid_invoice.reload.paid_history?).to be(true)
    end

    it "preserves paid installment state in actionable update messages when standalone mirrored exchanges are restructured" do
      receiver = create(:user, :random)
      receiver_entity = create(:entity, user:, entity_name: receiver.first_name.upcase, entity_user: receiver)
      create(:entity, user: receiver, entity_name: user.first_name.upcase, entity_user: user)

      transaction = create(
        :card_transaction,
        user:,
        context: user.main_context,
        user_card: user_card_one,
        description: "testing this shit",
        date: Time.zone.local(2026, 3, 30, 9, 56, 0),
        month: 4,
        year: 2026,
        price: -12_000
      )
      transaction.category_transactions.destroy_all
      transaction.category_transactions.create!(category: exchange_category)
      entity_transaction = transaction.entity_transactions.first
      entity_transaction.update!(entity_id: receiver_entity.id, price: -12_000, price_to_be_returned: -12_000, is_payer: true, exchanges_count: 2)

      first_exchange = create(
        :exchange,
        entity_transaction:,
        bound_type: :standalone,
        exchange_type: :monetary,
        number: 1,
        price: -6_000,
        date: Time.zone.local(2026, 3, 30, 9, 57, 0),
        month: 3,
        year: 2026
      )
      create(
        :exchange,
        entity_transaction:,
        bound_type: :standalone,
        exchange_type: :monetary,
        number: 2,
        price: -6_000,
        date: Time.zone.local(2026, 4, 30, 9, 57, 0),
        month: 4,
        year: 2026
      )

      exchange_return = first_exchange.cash_transaction.reload
      exchange_return.cash_installments.find_by!(number: 1).update!(paid: true, date: Time.zone.local(2026, 3, 30, 9, 57, 0))

      params = Params::CardTransactions.new
      params.use_base(transaction, card_transaction_options: { description: "testing this shit updated" })
      params.entity_transactions.first[:price] = -12_000
      params.entity_transactions.first[:price_to_be_returned] = -12_000
      params.entity_transactions.first[:exchanges_attributes][1][:price] = -2_000
      params.entity_transactions.first[:exchanges_attributes] << {
        number: 3,
        price: -2_000,
        exchange_type: :monetary,
        bound_type: :standalone,
        date: Time.zone.local(2026, 5, 30, 9, 57, 0),
        month: 5,
        year: 2026
      }
      params.entity_transactions.first[:exchanges_attributes] << {
        number: 4,
        price: -2_000,
        exchange_type: :monetary,
        bound_type: :standalone,
        date: Time.zone.local(2026, 6, 30, 9, 57, 0),
        month: 6,
        year: 2026
      }

      expect do
        put card_transaction_path(transaction), params: params.params, headers: turbo_stream_headers
      end.to change(Message.where(body: "notification:update"), :count).by(1)

      replay = Message.where(body: "notification:update").order(:id).last.replay_payload

      expect(response).to have_http_status(:ok)
      expect(replay.fetch("cash_installments_attributes")).to include(
        a_hash_including("number" => 1, "paid" => true),
        a_hash_including("number" => 2, "paid" => false),
        a_hash_including("number" => 3, "paid" => false),
        a_hash_including("number" => 4, "paid" => false)
      )
    end
  end

  describe "[ #month_year ]" do
    it "renders the pay in advance modal with autofocus on the date input" do
      card_transaction.description = "Pay in advance autofocus"
      post card_transactions_path, params: card_transaction.params, headers: turbo_stream_headers
      created_transaction = CardTransaction.order(:id).last
      installment = created_transaction.card_installments.first
      installment_month_year = "#{installment.year}#{installment.month.to_s.rjust(2, '0')}"

      get month_year_card_transactions_path, params: {
        user_card_id: user_card_one.id,
        month_year: installment_month_year,
        card_transaction: { user_card_id: user_card_one.id }
      }

      expect(response).to have_http_status(:ok)

      document = Nokogiri::HTML.fragment(response.body)
      modal_id = "cardTransactionModal_#{user_card_one.id}_#{installment.month}_#{installment.year}"
      date_input = document.at_css("##{modal_id} #card_transaction_date")

      expect(date_input["data-controller"]).to include("autofocus")
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

    it "allows confirmed destruction when a transaction has paid history and the cycle remains covered" do
      locked_transaction = create_card_transaction_with_paid_history(description: "Confirmed destroy card")
      create_supporting_card_transaction(invoice_cash_transaction: locked_transaction.card_installments.find_by!(number: 1).cash_transaction)

      expect do
        delete card_transaction_path(
          locked_transaction,
          card_installment_id: locked_transaction.card_installments.first.id,
          historical_correction_confirmation: true
        ), headers: turbo_stream_headers
      end.to change(CardTransaction, :count).by(-1)

      expect(response).to have_http_status(:ok)
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

    it "renders installment-specific destroy trigger ids in filtered month-year rows" do
      create_params = Params::CardTransactions.new(
        card_transaction: {
          description: "Destroy me from filtered index",
          price: -6_000,
          date: Date.new(2026, 3, 10),
          month: 3,
          year: 2026,
          user_id: user.id,
          user_card_id: user_card_one.id
        },
        card_installments: { count: 2 },
        category_transactions: [ { category_id: exchange_category.id } ],
        entity_transactions: [ {
          entity_id: entity_one.id,
          price: -6_000,
          price_to_be_returned: -6_000,
          exchanges_attributes: [
            { price: -3_000, exchange_type: :monetary, date: Date.new(2026, 3, 10), month: 3, year: 2026 },
            { price: -3_000, exchange_type: :monetary, date: Date.new(2026, 4, 10), month: 4, year: 2026 }
          ]
        } ]
      )

      post card_transactions_path, params: create_params.params, headers: turbo_stream_headers

      created_transaction = CardTransaction.order(:id).last
      installments = created_transaction.card_installments.order(:number).to_a

      get month_year_card_transactions_path, params: {
        user_card_id: user_card_one.id,
        month_year: "202603",
        card_transaction: { entity_id: [ entity_one.id ], user_card_id: user_card_one.id }
      }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("delete_card_transaction_#{created_transaction.id}_#{installments.first.id}")

      get month_year_card_transactions_path, params: {
        user_card_id: user_card_one.id,
        month_year: "202604",
        card_transaction: { entity_id: [ entity_one.id ], user_card_id: user_card_one.id }
      }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("delete_card_transaction_#{created_transaction.id}_#{installments.second.id}")
    end

    it "supports the canonical sort and direction params for month-year rows" do
      alpha = create(
        :card_transaction,
        user:,
        context: user.main_context,
        user_card: user_card_one,
        description: "Alpha dinner",
        price: -4_500,
        date: Date.new(2026, 3, 1),
        month: 3,
        year: 2026
      )
      create(
        :card_transaction,
        user:,
        context: user.main_context,
        user_card: user_card_one,
        description: "Zulu movie",
        price: -4_500,
        date: Date.new(2026, 3, 2),
        month: 3,
        year: 2026
      )

      first_installment = alpha.card_installments.first
      month_year = format("%<year>04d%<month>02d", year: first_installment.year, month: first_installment.month)

      get month_year_card_transactions_path, params: {
        user_card_id: user_card_one.id,
        month_year:,
        sort: "description",
        direction: "asc",
        card_transaction: { user_card_id: user_card_one.id }
      }

      expect(response).to have_http_status(:ok)
      expect(response.body.index("Alpha dinner")).to be < response.body.index("Zulu movie")
    end

    it "keeps the month-year response free of duplicated sort controls" do
      transaction = create(
        :card_transaction,
        user:,
        context: user.main_context,
        user_card: user_card_one,
        description: "Header controls",
        price: -4_500,
        date: Date.new(2026, 3, 1),
        month: 3,
        year: 2026
      )

      first_installment = transaction.card_installments.first
      month_year = format("%<year>04d%<month>02d", year: first_installment.year, month: first_installment.month)

      get month_year_card_transactions_path, params: {
        user_card_id: user_card_one.id,
        month_year:,
        sort: "installment_date",
        direction: "asc",
        card_transaction: { user_card_id: user_card_one.id }
      }

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include('data-sort-field="description"')
      expect(response.body).not_to include('data-sort-field="installment_date"')
      expect(response.body).not_to include('data-sort-field="transaction_date"')
      expect(response.body).not_to include('data-sort-field="price"')
    end

    it "keeps supporting legacy order_by while the new sort contract is rolling out" do
      late = create(
        :card_transaction,
        user:,
        context: user.main_context,
        user_card: user_card_one,
        description: "Late transaction",
        price: -2_500,
        date: Date.new(2026, 3, 7),
        month: 3,
        year: 2026
      )
      create(
        :card_transaction,
        user:,
        context: user.main_context,
        user_card: user_card_one,
        description: "Early transaction",
        price: -2_500,
        date: Date.new(2026, 3, 6),
        month: 3,
        year: 2026
      )

      first_installment = late.card_installments.first
      month_year = format("%<year>04d%<month>02d", year: first_installment.year, month: first_installment.month)

      get month_year_card_transactions_path, params: {
        user_card_id: user_card_one.id,
        month_year:,
        order_by: "transaction_date",
        card_transaction: { user_card_id: user_card_one.id }
      }

      expect(response).to have_http_status(:ok)
      expect(response.body.index("Early transaction")).to be < response.body.index("Late transaction")
    end

    it "renders Analyse links while keeping description links pointed at edit" do
      transaction = create(
        :card_transaction,
        user:,
        context: user.main_context,
        user_card: user_card_one,
        description: "Analysable card row",
        date: Date.new(2026, 3, 10),
        month: 4,
        year: 2026,
        card_installments: [
          build(:card_installment, number: 1, date: Date.new(2026, 4, 10), month: 4, year: 2026)
        ]
      )

      get month_year_card_transactions_path, params: {
        user_card_id: user_card_one.id,
        month_year: "202604",
        card_transaction: { user_card_id: user_card_one.id }
      }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(card_transaction_path(transaction))
      expect(response.body).to include(edit_card_transaction_path(transaction))
      expect(response.body).to include(I18n.t("actions.analyse"))

      document = Nokogiri::HTML.fragment(response.body)
      description_link = document.at_css("#edit_card_transaction_#{transaction.id}")

      expect(description_link["href"]).to eq(edit_card_transaction_path(transaction))
    end

    it "filters exchange rows by bound type" do
      card_bound_transaction = create(
        :card_transaction,
        user:,
        context: user.main_context,
        user_card: user_card_one,
        description: "Card-bound exchange row",
        date: Date.new(2026, 3, 10),
        month: 4,
        year: 2026,
        price: -2_000,
        category_transactions: [ build(:category_transaction, category: exchange_category, transactable: nil) ],
        entity_transactions: [],
        card_installments: [ build(:card_installment, number: 1, date: Date.new(2026, 4, 10), month: 4, year: 2026, price: -2_000) ]
      )
      payer_card_bound = create(
        :entity_transaction,
        transactable: card_bound_transaction,
        entity: entity_one,
        is_payer: true,
        price: -2_000,
        price_to_be_returned: -2_000
      )
      create(
        :exchange,
        entity_transaction: payer_card_bound,
        bound_type: :card_bound,
        exchange_type: :monetary,
        number: 1,
        price: -2_000,
        date: Date.new(2026, 4, 10),
        month: 4,
        year: 2026
      )

      standalone_transaction = create(
        :card_transaction,
        user:,
        context: user.main_context,
        user_card: user_card_one,
        description: "Standalone exchange row",
        date: Date.new(2026, 3, 11),
        month: 4,
        year: 2026,
        price: -2_500,
        category_transactions: [ build(:category_transaction, category: exchange_category, transactable: nil) ],
        entity_transactions: [],
        card_installments: [ build(:card_installment, number: 1, date: Date.new(2026, 4, 11), month: 4, year: 2026, price: -2_500) ]
      )
      payer_standalone = create(
        :entity_transaction,
        transactable: standalone_transaction,
        entity: entity_two,
        is_payer: true,
        price: -2_500,
        price_to_be_returned: -2_500
      )
      create(
        :exchange,
        entity_transaction: payer_standalone,
        bound_type: :standalone,
        exchange_type: :monetary,
        number: 1,
        price: -2_500,
        date: Date.new(2026, 4, 11),
        month: 4,
        year: 2026
      )

      get month_year_card_transactions_path, params: {
        user_card_id: user_card_one.id,
        month_year: "202604",
        exchange_bound_type: "card_bound",
        card_transaction: {
          user_card_id: user_card_one.id,
          category_id: [ exchange_category.id ]
        }
      }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Card-bound exchange row")
      expect(response.body).not_to include("Standalone exchange row")
    end
  end

  describe "[ #show ]" do
    it "renders a context-scoped dashboard with installments, allocations, invoices, links, and actions" do
      transaction = create(
        :card_transaction,
        user:,
        context: user.main_context,
        user_card: user_card_one,
        subscription:,
        description: "Card dashboard details",
        comment: "Dashboard card comment",
        price: -12_000,
        card_installments: [
          build(:card_installment, number: 1, date: Date.new(2026, 4, 10), month: 4, year: 2026, price: -6_000, paid: true),
          build(:card_installment, number: 2, date: Date.new(2026, 5, 10), month: 5, year: 2026, price: -6_000, paid: false)
        ],
        category_transactions: [ build(:category_transaction, category: exchange_category, transactable: nil) ],
        entity_transactions: [
          build(
            :entity_transaction,
            entity: entity_one,
            transactable: nil,
            price: -12_000,
            price_to_be_returned: -12_000,
            exchanges: [
              build(:exchange, price: -12_000, exchange_type: :monetary, date: Date.new(2026, 4, 10), month: 4, year: 2026)
            ]
          )
        ]
      )

      get card_transaction_path(transaction)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Card dashboard details")
      expect(response.body).to include("Dashboard card comment")
      expect(response.body).to include("Installments and Invoices")
      expect(response.body).not_to include(I18n.t("dashboards.sections.allocations"))
      expect(response.body).to include(I18n.t("dashboards.card_transactions.exchanges"))
      expect(response.body).to include(I18n.t("dashboards.status.partial"))
      expect(response.body).to include(exchange_category.name)
      expect(response.body).to include(entity_one.entity_name)
      expect(response.body).to include(subscription.description)
      expect(response.body).to include(edit_card_transaction_path(transaction))
      expect(response.body).to include(duplicate_card_transaction_path(transaction))
      expect(response.body).to include("border-orange-500")
      expect(response.body).to include(cash_transaction_path(transaction.card_installments.first.cash_transaction))
      expect(response.body).to include("user_card_id")
      expect(response.body).to include(user_card_one.id.to_s)
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

    it "drops duplicated payer entities that no longer have exchanges when replacing the entity with a regular one" do
      leisure_category = create(:category, user:, category_name: "LEISURE")

      exchange_duplicate_params = Params::CardTransactions.new(
        card_transaction: {
          description: "Original exchange transaction",
          price: -2_200,
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
          price: -2_200,
          price_to_be_returned: -2_200,
          exchanges_attributes: [
            { price: -2_200, exchange_type: :monetary, date: Time.zone.today, month: Time.zone.today.month, year: Time.zone.today.year }
          ]
        } ]
      )

      post card_transactions_path, params: exchange_duplicate_params.params, headers: turbo_stream_headers
      CardTransaction.last
      duplicated_params = Params::CardTransactions.new(
        card_transaction: {
          description: "Duplicated exchange replacement",
          price: -2_200,
          date: Time.zone.today,
          month: Time.zone.today.month,
          year: Time.zone.today.year,
          user_id: user.id,
          user_card_id: user_card_one.id
        },
        card_installments: { count: 1 },
        category_transactions: [ { category_id: leisure_category.id } ],
        entity_transactions: [
          {
            entity_id: entity_one.id,
            price: -2_200,
            price_to_be_returned: -2_200,
            exchanges_attributes: []
          },
          {
            entity_id: entity_two.id,
            price: 0,
            price_to_be_returned: 0,
            exchanges_attributes: []
          }
        ]
      )

      expect do
        post card_transactions_path, params: duplicated_params.params.merge(chain_mode: "duplicate"), headers: turbo_stream_headers
      end.to change(CardTransaction, :count).by(1)

      duplicated_transaction = CardTransaction.last

      expect(duplicated_transaction.categories.pluck(:id)).to contain_exactly(leisure_category.id)
      expect(duplicated_transaction.entities.pluck(:id)).to contain_exactly(entity_two.id)
      expect(duplicated_transaction.entity_transactions.find_by(entity_id: entity_two.id).exchanges.count).to eq(0)
      expect(duplicated_transaction.entity_transactions.find_by(entity_id: entity_one.id)).to be_nil
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

      derived_only_category = create(:category, :random, user:)
      create_params = Params::CardTransactions.new(
        card_transaction: {
          description: "Derived only card transaction",
          price: -11_000,
          date: Date.new(2036, 1, 12),
          month: 2,
          year: 2036,
          user_id: user.id,
          user_card_id: user_card_one.id
        },
        card_installments: { count: 1 },
        category_transactions: [ { category_id: derived_only_category.id } ],
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
      derived_only_card_transaction = derived_context.card_transactions.find_by!(description: "Derived only card transaction")

      update_params = Params::CardTransactions.new
      update_params.use_base(derived_card_transaction, card_transaction_options: { description: "Derived updated card transaction", price: -12_500 })
      update_params.card_installments.each { |installment| installment[:price] = -12_500 }

      put card_transaction_path(derived_card_transaction), params: update_params.params, headers: turbo_stream_headers

      expect(derived_card_transaction.reload.description).to eq("Derived updated card transaction")
      expect(derived_card_transaction.price).to eq(-12_500)
      expect(main_card_transaction.reload.description).to eq("Main isolated card transaction")
      expect(main_card_transaction.price).to eq(-9_000)

      card_installment_id = derived_only_card_transaction.card_installments.first.id

      expect do
        delete card_transaction_path(derived_only_card_transaction, card_installment_id:), headers: turbo_stream_headers
      end.to change { derived_context.card_transactions.reload.count }.by(-1)
                                                                      .and change { user.main_context.card_transactions.reload.count }.by(0)

      expect(CardTransaction.exists?(main_card_transaction.id)).to be(true)
      expect(derived_card_transaction.reload.description).to eq("Derived updated card transaction")
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

      get card_transaction_path(main_card_transaction)
      expect(response).to have_http_status(:not_found)

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
      expect(advanced_card_transaction.description).to eq(advanced_card_transaction.card_advance_description)
      expect(advanced_card_transaction.advance_cash_transaction).to be_present
      expect(advanced_card_transaction.advance_cash_transaction.description).to eq(advanced_card_transaction.card_advance_description)
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
