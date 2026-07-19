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

  def create_piggy_bank_source(description:, return_transaction: nil, price: 5_000)
    source = build(
      :cash_transaction,
      user:,
      context: user.main_context,
      user_bank_account:,
      description:,
      price: -price,
      cash_installments: [ build(:cash_installment, number: 1, price: -price, date: Time.zone.now) ],
      category_transactions: [ CategoryTransaction.new(category: user.built_in_category("PIGGY BANK")) ],
      entity_transactions: [ EntityTransaction.new(entity:, price: 0, price_to_be_returned: 0, is_payer: false) ],
      piggy_bank: PiggyBank.new(return_price: price, return_date: 3.months.from_now, return_cash_transaction: return_transaction)
    )
    source.save!
    source
  end

  describe "[ #new ]" do
    it "renders RubyUI comboboxes and split datetime input for bank account, category, and entity selection" do
      get new_cash_transaction_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include('data-controller="form-loading"')
      expect(response.body).to include('id="cash_transaction_form_submission_skeleton"')
      expect(response.body).to include('data-controller="ruby-ui--combobox"')
      expect(response.body).to include('data-controller="datetime-input"')
      expect(response.body).to include('data-controller="nested-form installment-lock installments-display"')
      expect(response.body).to include('data-controller="nested-form form-collection-carousel"')
      expect(response.body).to include('id="cash_transaction_date"')
      expect(response.body).to include('id="cash_transaction_date_time_input"')
      expect(response.body).to include('id="piggy_bank_category_id"')
      expect(response.body).to include('data-piggy-bank-mode="piggy"')
      expect(response.body).to include("piggy_bank_return_mode_NEW_RECORD")
      expect(response.body).to include("data-piggy-bank-return-selector")
      expect(response.body).not_to include("hw-combobox")

      document = Nokogiri::HTML.fragment(response.body)
      installment_dates = document.css("input.installment_date")
      active_installment_date = installment_dates.find { |input| input["name"].exclude?("NEW_RECORD") }
      datetime_wrapper = active_installment_date.ancestors.find { |node| node["data-controller"] == "datetime-input" }

      expect(installment_dates.map { |input| input["id"] }).to contain_exactly("installment_date_NEW_RECORD", "installment_date_0")
      expect(active_installment_date["type"]).to eq("hidden")
      expect(active_installment_date["name"]).to eq("cash_transaction[cash_installments_attributes][0][date]")
      expect(active_installment_date["data-reactive-form-target"]).to eq("dateInput")
      expect(active_installment_date["data-action"]).to eq("input->reactive-form#setPaidIfPastCurrentDay")
      expect(datetime_wrapper["data-datetime-input-readonly-value"]).to be_nil
      expect(datetime_wrapper.at_css("#installment_date_0_date_input")).to be_present
      expect(datetime_wrapper.at_css("#installment_date_0_time_input")).to be_present
    end

    it "renders paid installment datetimes as read-only while keeping their canonical values enabled" do
      locked_transaction = create_cash_transaction_with_paid_history

      get edit_cash_transaction_path(locked_transaction)

      document = Nokogiri::HTML.fragment(response.body)
      installment_dates = document.css("input.installment_date").reject { |input| input["name"].include?("NEW_RECORD") }
      paid_date = installment_dates.find { |input| input["value"].start_with?("2026-03-10") }
      unpaid_date = installment_dates.find { |input| input["value"].start_with?("2026-04-10") }
      paid_wrapper = paid_date.ancestors.find { |node| node["data-controller"] == "datetime-input" }
      unpaid_wrapper = unpaid_date.ancestors.find { |node| node["data-controller"] == "datetime-input" }

      expect(paid_date["disabled"]).to be_nil
      expect(paid_wrapper["data-datetime-input-readonly-value"]).to eq("")
      expect(paid_wrapper.at_css("input[type='date']")["disabled"]).to eq("disabled")
      expect(paid_wrapper.at_css("input[id$='_time_input']")["disabled"]).to eq("disabled")
      expect(unpaid_wrapper["data-datetime-input-readonly-value"]).to be_nil
      expect(unpaid_wrapper.at_css("input[type='date']")["disabled"]).to be_nil
      expect(unpaid_wrapper.at_css("input[id$='_time_input']")["disabled"]).to be_nil
    end

    it "renders the cash-specific form skeleton on edit" do
      existing_cash_transaction = create(
        :cash_transaction,
        user:,
        context: user.main_context,
        user_bank_account:,
        description: "Existing cash transaction",
        price: 12_345,
        date: Date.new(2026, 4, 2),
        month: 4,
        year: 2026
      )

      get edit_cash_transaction_path(existing_cash_transaction)

      expect(response).to have_http_status(:success)
      expect(response.body).to include('data-controller="form-loading"')
      expect(response.body).to include('id="cash_transaction_form_submission_skeleton"')
      expect(response.body).to include('name="cash_transaction[historical_correction_confirmation]"')
    end

    it "lists every grouped contribution on a Piggy Bank return edit form" do
      first_source = create_piggy_bank_source(description: "First reserve")
      grouped_return = first_source.piggy_bank.return_cash_transaction
      second_source = create_piggy_bank_source(description: "Second reserve", return_transaction: grouped_return, price: 2_000)
      investment = create(
        :investment,
        user:,
        context: user.main_context,
        user_bank_account:,
        investment_type: create(:investment_type, :random),
        piggy_bank_return_cash_transaction: grouped_return,
        description: "July Piggy Bank profit",
        price: 300,
        date: Time.zone.today,
        month: Time.zone.today.month,
        year: Time.zone.today.year
      )

      get edit_cash_transaction_path(grouped_return)

      expect(response).to have_http_status(:success)
      expect(response.body).to include(I18n.t("piggy_banks.contributions", count: 2))
      expect(response.body).to include("First reserve", "Second reserve")
      expect(response.body).to include(edit_cash_transaction_path(first_source), edit_cash_transaction_path(second_source))
      expect(response.body).to include('id="piggy_bank_contributions_sheet_trigger"')
      expect(response.body).to include('id="piggy_bank_investments_sheet_trigger"')
      expect(response.body).to include('id="piggy_bank_cash_month_year_')
      expect(response.body).to include('id="month_year_container_piggy_bank_investment_')
      expect(response.body).to include("July Piggy Bank profit")
      expect(response.body).to include(edit_investment_path(investment))
    end

    it "renders the bulk add to subscription action on the index" do
      get cash_transactions_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include(I18n.t("actions.add_to_subscription"))
    end

    it "renders budget bulk action controls on the index" do
      get cash_transactions_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include('data-bulk-selection-kind="budget"')
      expect(response.body).to include('data-bulk-ids-kind="budget"')
      expect(response.body).to include('data-bulk-form-id="bulk_budget_make_inclusive_form"')
      expect(response.body).to include('name="return_to"')
      expect(response.body).to include('value="/cash_transactions"')
      expect(response.body).to include(I18n.t("bulk_actions.budgets.make_inclusive"))
      expect(response.body).to include(I18n.t("bulk_actions.budgets.make_exclusive"))
      expect(response.body).to include(I18n.t("bulk_actions.budgets.first_installment_only"))
      expect(response.body).to include(I18n.t("bulk_actions.budgets.all_installments"))
    end

    it "uses canonical sort fields on the index form" do
      get cash_transactions_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include('name="sort"')
      expect(response.body).to include('name="direction"')
      expect(response.body).to include('data-sort-field="default"')
      expect(response.body).to include('data-sort-field="installment_date"')
      expect(response.body).to include('data-sort-field="transaction_date"')
      expect(response.body).to include('data-sort-field="description"')
      expect(response.body).to include('data-sort-field="price"')
    end

    it "renders the mobile sort preset select" do
      get cash_transactions_path, headers: { "HTTP_USER_AGENT" => "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)" }

      expect(response).to have_http_status(:success)
      expect(response.body).to include('id="cash_transactions_sort_preset"')
      expect(response.body).to include('data-action="change-&gt;datatable#applySortPreset"')

      document = Nokogiri::HTML.fragment(response.body)
      expect(document.at_css("form#search_form #cash_transactions_sort_preset")).to be_present
    end

    it "keeps advanced filter range fields blank until the user fills them" do
      get cash_transactions_path

      expect(response).to have_http_status(:success)
      expect(response.body).not_to match(/name="from_installments_count"[^>]*value="1"|value="1"[^>]*name="from_installments_count"/)
      expect(response.body).not_to match(/name="to_installments_count"[^>]*value="72"|value="72"[^>]*name="to_installments_count"/)
      expect(response.body).to include("price-mask#toggleSign")
      expect(response.body).to include('data-sign="+"')
      expect(response.body).to include("price-range-from-ct-price")
      expect(response.body).to include("price-range-to-price")
    end

    it "renders a filter summary and explicit paid-state control when cash filters are active" do
      get cash_transactions_path, params: {
        search_term: "rent",
        paid_state: "pending",
        cash_transaction: {
          category_id: [ category.id ],
          user_bank_account_id: [ user_bank_account.id ]
        }
      }

      expect(response).to have_http_status(:success)
      expect(response.body).to include(I18n.t("filters.summary.active"))
      expect(response.body).to include(I18n.t("filters.summary.clear"))
      expect(response.body).to include(I18n.t("filters.summary.items.paid_state", value: I18n.t("filters.paid_state.pending")))
      expect(response.body).to include("paid_state=pending")

      document = Nokogiri::HTML.fragment(response.body)
      chips = document.css("a[aria-label^=\"#{I18n.t('filters.summary.clear')}\"]")
      paid_state_chip = chips.find do |chip|
        chip.text.include?(I18n.t("filters.summary.items.paid_state", value: I18n.t("filters.paid_state.pending")))
      end

      expect(paid_state_chip).to be_present
      expect(paid_state_chip["href"]).to include("search_term=rent")
      expect(paid_state_chip["href"]).not_to include("paid_state=")
      expect(paid_state_chip["title"]).to eq(I18n.t("filters.summary.items.paid_state", value: I18n.t("filters.paid_state.pending")))
      expect(paid_state_chip.text).to end_with("x")
    end

    it "keeps the exchange bound type filter selected for exchange return filters" do
      get cash_transactions_path, params: {
        exchange_bound_type: "card_bound",
        cash_transaction: {
          category_id: [ user.built_in_category("EXCHANGE RETURN").id ]
        }
      }

      expect(response).to have_http_status(:success)
      expect(response.body).to include(I18n.t("filters.summary.items.exchange_bound_type", value: I18n.t("filters.exchange_bound_type.card_bound")))
      expect(response.body).to include('name="exchange_bound_type"')
      expect(response.body).to include('id="exchange_bound_type"')
      expect(response.body).to include('form="search_form"')
      expect(response.body).to include('data-controller="request-submit"')
      expect(response.body).to include('data-request-submit-form-id-value="search_form"')
    end

    it "shows the exchange bound type filter for exchange return and not for exchange" do
      get cash_transactions_path, params: {
        cash_transaction: {
          category_id: [ user.built_in_category("EXCHANGE RETURN").id ]
        }
      }

      expect(response).to have_http_status(:success)
      expect(response.body).to include('id="exchange_bound_type"')

      get cash_transactions_path, params: {
        cash_transaction: {
          category_id: [ user.built_in_category("EXCHANGE").id ]
        }
      }

      expect(response).to have_http_status(:success)
      expect(response.body).not_to include('id="exchange_bound_type"')
    end

    it "does not cap the transfer bulk action date" do
      get cash_transactions_path

      expect(response).to have_http_status(:success)

      document = Nokogiri::HTML.fragment(response.body)
      transfer_date_input = document.at_css("#cash_installments_multiple_transfer_date")
      transfer_datetime_wrapper = transfer_date_input.ancestors.find { |node| node["data-controller"] == "datetime-input" }
      payment_date_input = document.at_css("#cash_installments_multiple_payment_date")
      payment_datetime_wrapper = payment_date_input.ancestors.find { |node| node["data-controller"] == "datetime-input" }

      expect(transfer_datetime_wrapper["data-datetime-input-max-datetime-value"]).to be_blank
      expect(payment_datetime_wrapper["data-datetime-input-max-datetime-value"]).to be_present
    end

    it "renders autofocus targets for pay multiple and transfer modals" do
      get cash_transactions_path

      expect(response).to have_http_status(:success)

      document = Nokogiri::HTML.fragment(response.body)
      pay_multiple_date = document.at_css("#cash_installments_multiple_payment_date_date_input")
      transfer_reference = document.at_css("select[name='reference_date']")

      expect(pay_multiple_date["data-controller"]).to include("autofocus")
      expect(transfer_reference["data-controller"]).to include("autofocus")
    end
  end

  describe "[ #show ]" do
    it "renders a context-scoped dashboard with installments, exchanges, links, and actions" do
      transaction = create(
        :cash_transaction,
        user:,
        context: user.main_context,
        user_bank_account:,
        subscription:,
        description: "Cash dashboard details",
        comment: "Dashboard comment",
        price: 12_000,
        date: Date.new(2026, 4, 15),
        month: 4,
        year: 2026,
        cash_installments: [
          build(:cash_installment, number: 1, date: Date.new(2026, 4, 15), month: 4, year: 2026, price: 6_000, balance: 6_000, paid: true),
          build(:cash_installment, number: 2, date: Date.new(2026, 5, 15), month: 5, year: 2026, price: 6_000, balance: 12_000, paid: false)
        ]
      )
      create(:category_transaction, transactable: transaction, category:)
      entity_transaction = create(:entity_transaction, transactable: transaction, entity:, price: 0, price_to_be_returned: 6_000, is_payer: true)
      create(:exchange, entity_transaction:, cash_transaction: transaction, number: 1, date: Date.new(2026, 4, 15), month: 4, year: 2026, price: 6_000,
                        bound_type: :standalone)
      get cash_transaction_path(transaction)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Cash dashboard details")
      expect(response.body).to include("Dashboard comment")
      expect(response.body).to include(I18n.t("dashboards.sections.installments"))
      expect(response.body).to include(I18n.t("dashboards.sections.summary"))
      expect(response.body).to include(I18n.t("dashboards.card_transactions.exchanges"))
      expect(response.body).to include(I18n.t("dashboards.status.partial"))
      expect(response.body).to include(category.name)
      expect(response.body).to include(entity.entity_name)
      expect(response.body).to include(subscription.description)
      expect(response.body).to include(edit_cash_transaction_path(transaction))
      expect(response.body).to include(duplicate_cash_transaction_path(transaction))
      expect(response.body).to include("border-orange-500")
      expect(response.body).to include("cashInstallmentModal_#{transaction.cash_installments.second.id}")
      expect(response.body).to include(user_bank_account.user_bank_account_name)
    end

    it "does not render broken reference links to transactions outside the current context" do
      foreign_user = create(:user, :random)
      foreign_bank = create(:bank, :random)
      foreign_account = create(:user_bank_account, :random, user: foreign_user, bank: foreign_bank)
      foreign_transaction = create(
        :cash_transaction,
        user: foreign_user,
        context: foreign_user.main_context,
        user_bank_account: foreign_account,
        description: "Foreign reference transaction",
        price: -8_000,
        date: Date.new(2026, 4, 10),
        month: 4,
        year: 2026
      )
      transaction = create(
        :cash_transaction,
        user:,
        context: user.main_context,
        user_bank_account:,
        description: "Local borrow return",
        price: 8_000,
        date: Date.new(2026, 4, 11),
        month: 4,
        year: 2026,
        reference_transactable: foreign_transaction
      )

      get cash_transaction_path(transaction)

      expect(response).to have_http_status(:success)
      expect(response.body).not_to include(cash_transaction_path(foreign_transaction))
    end

    it "renders card-bound projection exchanges and can resync a mismatched projection total" do
      exchange_return_category = user.built_in_category("EXCHANGE RETURN")
      user_card = create(:user_card, :random, user:, card: create(:card, :random))
      source_card = create(
        :card_transaction,
        user:,
        context: user.main_context,
        user_card:,
        description: "Projection source",
        price: -5_000,
        date: Time.zone.parse("2026-08-03 12:00:00"),
        month: 8,
        year: 2026,
        card_installments: [
          build(:card_installment, number: 1, price: -5_000, date: Time.zone.parse("2026-08-03 12:00:00"), month: 8, year: 2026)
        ]
      )
      payer = source_card.entity_transactions.first
      payer.update_columns(entity_id: entity.id, is_payer: true, price: 5_000, price_to_be_returned: 5_000, exchanges_count: 1)
      projection = create(
        :cash_transaction,
        user:,
        context: user.main_context,
        user_bank_account:,
        cash_transaction_type: "Exchange",
        description: "[ 08/2026 ] LALA - CARD",
        date: Time.zone.parse("2026-08-10 12:00:00"),
        month: 8,
        year: 2026,
        price: 6_000,
        cash_installments: [
          build(:cash_installment, number: 1, price: 6_000, date: Time.zone.parse("2026-08-10 12:00:00"), month: 8, year: 2026)
        ]
      )
      projection.categories = [ exchange_return_category ]
      projection.save!
      Exchange.insert({
                        entity_transaction_id: payer.id,
                        cash_transaction_id: projection.id,
                        exchange_type: Exchange.exchange_types.fetch(:monetary),
                        bound_type: "card_bound",
                        number: 1,
                        price: 5_000,
                        starting_price: 5_000,
                        date: Time.zone.parse("2026-08-10 12:00:00"),
                        month: 8,
                        year: 2026,
                        exchanges_count: 1,
                        created_at: Time.current,
                        updated_at: Time.current
                      })

      get cash_transaction_path(projection)

      expect(response).to have_http_status(:success)
      expect(response.body).to include(I18n.t("cash_transactions.exchange_projection.title"))
      expect(response.body).to include(I18n.t("cash_transactions.exchange_projection.fix"))
      expect(response.body).to include(card_transaction_path(source_card))

      projection.cash_installments.update_all(balance: nil, order_id: nil)

      patch fix_exchange_projection_cash_transaction_path(projection)

      expect(response).to redirect_to(cash_transaction_path(projection))
      expect(projection.reload.price).to eq(5_000)
      expect(projection.cash_installments.reload.sum(:price)).to eq(5_000)
      expect(projection.cash_installments.first.balance).not_to be_nil
    end

    it "shows the fix button when card-bound projection exchange buckets are stale even if totals match" do
      exchange_return_category = user.built_in_category("EXCHANGE RETURN")
      user_card = create(:user_card, :random, user:, card: create(:card, :random))
      source_card = create(
        :card_transaction,
        user:,
        context: user.main_context,
        user_card:,
        description: "Merged bill source",
        price: -5_000,
        date: Time.zone.parse("2026-06-03 12:00:00"),
        month: 8,
        year: 2026,
        card_installments: [
          build(:card_installment, number: 1, price: -5_000, date: Time.zone.parse("2026-06-03 12:00:00"), month: 8, year: 2026)
        ]
      )
      payer = source_card.entity_transactions.first
      payer.update_columns(entity_id: entity.id, is_payer: true, price: 5_000, price_to_be_returned: 5_000, exchanges_count: 1)
      stale_projection = create(
        :cash_transaction,
        user:,
        context: user.main_context,
        user_bank_account:,
        cash_transaction_type: "Exchange",
        description: "[ 07/2026 ] LALA - CARD",
        date: Time.zone.parse("2026-07-10 12:00:00"),
        month: 7,
        year: 2026,
        price: 5_000,
        cash_installments: [
          build(:cash_installment, number: 1, price: 5_000, date: Time.zone.parse("2026-07-10 12:00:00"), month: 7, year: 2026)
        ]
      )
      stale_projection.categories = [ exchange_return_category ]
      stale_projection.save!
      Exchange.insert({
                        entity_transaction_id: payer.id,
                        cash_transaction_id: stale_projection.id,
                        exchange_type: Exchange.exchange_types.fetch(:monetary),
                        bound_type: "card_bound",
                        number: 1,
                        price: 5_000,
                        starting_price: 5_000,
                        date: Time.zone.parse("2026-07-10 12:00:00"),
                        month: 7,
                        year: 2026,
                        exchanges_count: 1,
                        created_at: Time.current,
                        updated_at: Time.current
                      })
      target_source_card = create(
        :card_transaction,
        user:,
        context: user.main_context,
        user_card:,
        description: "Target bill source",
        price: -3_000,
        date: Time.zone.parse("2026-07-03 12:00:00"),
        month: 8,
        year: 2026,
        card_installments: [
          build(:card_installment, number: 1, price: -3_000, date: Time.zone.parse("2026-07-03 12:00:00"), month: 8, year: 2026)
        ]
      )
      target_payer = target_source_card.entity_transactions.first
      target_payer.update_columns(entity_id: entity.id, is_payer: true, price: 3_000, price_to_be_returned: 3_000, exchanges_count: 1)
      target_projection = create(
        :cash_transaction,
        user:,
        context: user.main_context,
        user_bank_account:,
        user_card:,
        cash_transaction_type: "Exchange",
        description: "[ 08/2026 ] #{entity.entity_name} - #{user_card.user_card_name}",
        date: Time.zone.parse("2026-08-10 12:00:00"),
        month: 8,
        year: 2026,
        price: 3_000,
        cash_installments: [
          build(:cash_installment, number: 1, price: 3_000, date: Time.zone.parse("2026-08-10 12:00:00"), month: 8, year: 2026)
        ]
      )
      target_projection.categories = [ exchange_return_category ]
      target_projection.save!
      Exchange.insert({
                        entity_transaction_id: target_payer.id,
                        cash_transaction_id: target_projection.id,
                        exchange_type: Exchange.exchange_types.fetch(:monetary),
                        bound_type: "card_bound",
                        number: 1,
                        price: 3_000,
                        starting_price: 3_000,
                        date: Time.zone.parse("2026-08-10 12:00:00"),
                        month: 8,
                        year: 2026,
                        exchanges_count: 1,
                        created_at: Time.current,
                        updated_at: Time.current
                      })

      get cash_transaction_path(stale_projection)

      expect(response).to have_http_status(:success)
      expect(response.body).to include(I18n.t("cash_transactions.exchange_projection.fix"))

      patch fix_exchange_projection_cash_transaction_path(stale_projection)

      expect(response).to redirect_to(cash_transaction_path(target_projection))
      expect(CashTransaction.exists?(stale_projection.id)).to be(false)
      expect(target_projection.reload.month).to eq(8)
      expect(target_projection.price).to eq(8_000)
      expect(target_projection.exchanges.reload.pluck(:month).uniq).to eq([ 8 ])
      expect(target_projection.exchanges.count).to eq(2)
    end

    it "rehomes card-bound projection exchanges that are attached to the wrong cash transaction bucket" do
      exchange_return_category = user.built_in_category("EXCHANGE RETURN")
      user_card = create(:user_card, :random, user:, card: create(:card, :random))
      august_source = create(
        :card_transaction,
        user:,
        context: user.main_context,
        user_card:,
        description: "August source",
        price: -5_000,
        date: Time.zone.parse("2026-08-03 12:00:00"),
        month: 8,
        year: 2026,
        card_installments: [
          build(:card_installment, number: 1, price: -5_000, date: Time.zone.parse("2026-08-03 12:00:00"), month: 8, year: 2026)
        ]
      )
      september_source = create(
        :card_transaction,
        user:,
        context: user.main_context,
        user_card:,
        description: "September source",
        price: -7_000,
        date: Time.zone.parse("2026-09-03 12:00:00"),
        month: 9,
        year: 2026,
        card_installments: [
          build(:card_installment, number: 1, price: -7_000, date: Time.zone.parse("2026-09-03 12:00:00"), month: 9, year: 2026)
        ]
      )
      october_source = create(
        :card_transaction,
        user:,
        context: user.main_context,
        user_card:,
        description: "October source",
        price: -4_000,
        date: Time.zone.parse("2026-10-03 12:00:00"),
        month: 10,
        year: 2026,
        card_installments: [
          build(:card_installment, number: 1, price: -4_000, date: Time.zone.parse("2026-10-03 12:00:00"), month: 10, year: 2026)
        ]
      )
      existing_september_source = create(
        :card_transaction,
        user:,
        context: user.main_context,
        user_card:,
        description: "Existing September source",
        price: -3_000,
        date: Time.zone.parse("2026-09-04 12:00:00"),
        month: 9,
        year: 2026,
        card_installments: [
          build(:card_installment, number: 1, price: -3_000, date: Time.zone.parse("2026-09-04 12:00:00"), month: 9, year: 2026)
        ]
      )
      [ august_source, september_source, october_source, existing_september_source ].each do |source|
        source.entity_transactions.first.update_columns(
          entity_id: entity.id,
          is_payer: true,
          price: source.price.abs,
          price_to_be_returned: source.price.abs,
          exchanges_count: 1
        )
      end
      august_projection = create(
        :cash_transaction,
        user:,
        context: user.main_context,
        user_bank_account:,
        user_card:,
        cash_transaction_type: "Exchange",
        description: "[ 08/2026 ] #{entity.entity_name} - #{user_card.user_card_name}",
        date: Time.zone.parse("2026-08-10 12:00:00"),
        month: 8,
        year: 2026,
        price: 16_000,
        cash_installments: [
          build(:cash_installment, number: 1, price: 16_000, date: Time.zone.parse("2026-08-10 12:00:00"), month: 8, year: 2026)
        ]
      )
      september_projection = create(
        :cash_transaction,
        user:,
        context: user.main_context,
        user_bank_account:,
        user_card:,
        cash_transaction_type: "Exchange",
        description: "[ 09/2026 ] #{entity.entity_name} - #{user_card.user_card_name}",
        date: Time.zone.parse("2026-09-10 12:00:00"),
        month: 9,
        year: 2026,
        price: 3_000,
        cash_installments: [
          build(:cash_installment, number: 1, price: 3_000, date: Time.zone.parse("2026-09-10 12:00:00"), month: 9, year: 2026)
        ]
      )
      august_projection.categories = [ exchange_return_category ]
      september_projection.categories = [ exchange_return_category ]
      august_projection.save!
      september_projection.save!

      [
        [ august_source, august_projection, 5_000, 8 ],
        [ september_source, august_projection, 7_000, 9 ],
        [ october_source, august_projection, 4_000, 10 ],
        [ existing_september_source, september_projection, 3_000, 9 ]
      ].each do |source, projection, price, month|
        Exchange.insert({
                          entity_transaction_id: source.entity_transactions.first.id,
                          cash_transaction_id: projection.id,
                          exchange_type: Exchange.exchange_types.fetch(:monetary),
                          bound_type: "card_bound",
                          number: 1,
                          price:,
                          starting_price: price,
                          date: Time.zone.parse("2026-#{month.to_s.rjust(2, '0')}-10 12:00:00"),
                          month:,
                          year: 2026,
                          exchanges_count: 1,
                          created_at: Time.current,
                          updated_at: Time.current
                        })
      end

      get cash_transaction_path(august_projection)

      expect(response).to have_http_status(:success)
      expect(response.body).to include(I18n.t("cash_transactions.exchange_projection.fix"))

      get cash_transaction_path(september_projection)

      expect(response).to have_http_status(:success)
      expect(response.body).to include(I18n.t("cash_transactions.exchange_projection.fix"))

      patch fix_exchange_projection_cash_transaction_path(august_projection)

      october_projection = CashTransaction.exchange_return.find_by!(
        user_card:,
        description: "[ 10/2026 ] #{entity.entity_name} - #{user_card.user_card_name}",
        month: 10,
        year: 2026
      )

      expect(response).to redirect_to(cash_transaction_path(august_projection))
      expect(august_projection.reload.price).to eq(5_000)
      expect(august_projection.exchanges.reload.pluck(:month).uniq).to eq([ 8 ])
      expect(september_projection.reload.price).to eq(10_000)
      expect(september_projection.exchanges.reload.pluck(:month).uniq).to eq([ 9 ])
      expect(september_projection.exchanges.count).to eq(2)
      expect(october_projection.price).to eq(4_000)
      expect(october_projection.exchanges.reload.pluck(:month).uniq).to eq([ 10 ])
    end
  end

  describe "[ #duplicate ]" do
    it "renders a duplicated cash transaction form without creating a new record" do
      existing_cash_transaction = create(
        :cash_transaction,
        user:,
        context: user.main_context,
        user_bank_account: user_bank_account,
        description: "Duplicated cash transaction",
        price: 12_345,
        date: Date.new(2026, 4, 2),
        month: 4,
        year: 2026
      )

      expect { get duplicate_cash_transaction_path(existing_cash_transaction) }.not_to change(CashTransaction, :count)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Duplicating")
      expect(response.body).to match(/name="chain_mode"[^>]*value="duplicate"/)
    end
  end

  describe "[ #add_to_subscription ]" do
    it "adds the selected cash transactions to the chosen subscription" do
      other_subscription = create(:subscription, user:, description: "Utilities bundle")
      first_transaction = create(
        :cash_transaction,
        user:,
        context: user.main_context,
        user_bank_account: user_bank_account,
        description: "Water bill",
        price: 4_500,
        date: Date.new(2026, 4, 3),
        month: 4,
        year: 2026
      )
      second_transaction = create(
        :cash_transaction,
        user:,
        context: user.main_context,
        user_bank_account: user_bank_account,
        description: "Power bill",
        price: 7_500,
        date: Date.new(2026, 4, 4),
        month: 4,
        year: 2026
      )

      post add_to_subscription_cash_transactions_path,
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

    it "merges subscription categories and entities into a paid-history cash transaction" do
      leisure = create(:category, user:, category_name: "LEISURE")
      nous = create(:entity, user:, entity_name: "NOUS")
      moi = user.built_in_entity
      subscription = create(:subscription, user:, description: "Club", comment: "Shared")
      subscription.categories << leisure
      subscription.entities << nous

      transaction = create_cash_transaction_with_paid_history(description: "Cinema")
      transaction.categories = [ leisure ]
      transaction.entities = [ moi ]
      transaction.save!(validate: false)

      post add_to_subscription_cash_transactions_path,
           params: {
             ids: transaction.id.to_s,
             subscription_id: subscription.id,
             index_context_json: {}.to_json
           },
           headers: turbo_stream_headers

      expect(response).to have_http_status(:success)

      transaction.reload
      expect(transaction.subscription).to eq(subscription)
      expect(transaction.categories.pluck(:category_name)).to contain_exactly("LEISURE", "SUBSCRIPTION")
      expect(transaction.entities.pluck(:entity_name)).to contain_exactly("MOI", "NOUS")
      expect(transaction.description).to eq("Club")
      expect(transaction.comment).to eq("Barbecue at Aunt's\nCinema")
    end

    it "keeps the installment reference month when attaching a cash transaction with stale parent month data" do
      subscription = create(:subscription, user:, description: "Reference-safe subscription")
      transaction = create(
        :cash_transaction,
        user:,
        context: user.main_context,
        user_bank_account:,
        description: "April installment",
        price: 8_000,
        date: Time.zone.local(2026, 4, 12),
        month: 12,
        year: 2026
      )
      installment = transaction.cash_installments.first
      installment.update_columns(
        date: Time.zone.local(2026, 4, 12, 14, 59),
        month: 4,
        year: 2026
      )

      post add_to_subscription_cash_transactions_path,
           params: {
             ids: transaction.id.to_s,
             subscription_id: subscription.id,
             index_context_json: {}.to_json
           },
           headers: turbo_stream_headers

      expect(response).to have_http_status(:success)
      expect(installment.reload.attributes.values_at("month", "year", "date")).to eq([ 4, 2026, Time.zone.local(2026, 4, 12, 14, 59) ])
    end
  end

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
    it "continues a create chain with the created ids tracked in the next form" do
      expect do
        post cash_transactions_path,
             params: cash_transaction.params.merge(chain_mode: "create", continue_chain: "1"),
             headers: turbo_stream_headers
      end.to change(CashTransaction, :count).by(1)

      created_cash_transaction = CashTransaction.last

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Chain Creating")
      expect(response.body).to match(/name="chain_mode"[^>]*value="create"/)
      expect(response.body).to match(/name="chain_record_ids\[\]"[^>]*value="#{created_cash_transaction.id}"/)
      expect(response.body).to include('name="continue_chain" value="1"')
      expect(response.body).to include("checked")
    end

    it "finishes a chain without saving the current cash transaction form" do
      existing_cash_transaction = create(
        :cash_transaction,
        user:,
        context: user.main_context,
        user_bank_account: user_bank_account,
        description: "Existing chained cash transaction",
        price: 12_345,
        date: Date.new(2026, 4, 3),
        month: 4,
        year: 2026
      )

      expect do
        post cash_transactions_path,
             params: {
               chain_mode: "create",
               chain_record_ids: [ existing_cash_transaction.id ],
               finish_chain_without_save: "1",
               cash_transaction: {
                 description: "",
                 price: "",
                 date: "",
                 user_id: user.id,
                 user_bank_account_id: user_bank_account.id
               }
             },
             headers: turbo_stream_headers
      end.not_to change(CashTransaction, :count)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("month_year_container_202604")
      expect(response.body).to include("cash_transaction%5Bcash_installment_ids%5D")
      expect(response.body).not_to include("Chain Creating")
    end

    it "keeps duplicate chain controls checked on hidden update submits" do
      post cash_transactions_path, params: {
        chain_mode: "duplicate",
        continue_chain: "1",
        commit: "Update",
        cash_transaction: {
          description: "Duplicate preview",
          date: Time.zone.today,
          month: Time.zone.today.month,
          year: Time.zone.today.year,
          price: 1000,
          user_id: user.id,
          user_bank_account_id: user_bank_account.id,
          cash_installments_attributes: [
            { number: 1, date: Time.zone.today, month: Time.zone.today.month, year: Time.zone.today.year, price: 1000, paid: false }
          ],
          category_transactions_attributes: [
            { category_id: category.id }
          ],
          entity_transactions_attributes: [
            { entity_id: entity.id, price: 0, price_to_be_returned: 0, exchanges_attributes: [] }
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
        post cash_transactions_path, params: {
          chain_mode: "duplicate",
          continue_chain: "1",
          cash_transaction: {
            description: "Duplicated cash transaction",
            price: 20_000,
            date: Time.zone.today,
            month: Time.zone.today.month,
            year: Time.zone.today.year,
            user_id: user.id,
            user_bank_account_id: user_bank_account.id,
            cash_installments_attributes: [
              { number: 1, date: Time.zone.today, month: Time.zone.today.month, year: Time.zone.today.year, price: 20_000, paid: false }
            ],
            category_transactions_attributes: [
              { category_id: category.id },
              { category_id: category.id },
              { category_id: extra_category.id }
            ],
            entity_transactions_attributes: [
              { entity_id: entity.id, price: 0, price_to_be_returned: 0, exchanges_attributes: [] },
              { entity_id: entity.id, price: 0, price_to_be_returned: 0, exchanges_attributes: [] },
              { entity_id: extra_entity.id, price: 0, price_to_be_returned: 0, exchanges_attributes: [] }
            ]
          }
        }, headers: turbo_stream_headers
      end.to change(CashTransaction, :count).by(1)

      created_cash_transaction = CashTransaction.last

      expect(response).to have_http_status(:success)
      expect(created_cash_transaction.categories).to contain_exactly(category, extra_category)
      expect(created_cash_transaction.entities).to contain_exactly(entity, extra_entity)
    end

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

    it "creates a linked Piggy Bank return from nested source input" do
      return_date = 3.months.from_now.change(sec: 0)
      piggy_bank_category = user.built_in_category("PIGGY BANK")

      expect do
        post cash_transactions_path, params: {
          cash_transaction: {
            description: "Emergency reserve",
            price: -5_000,
            date: Time.zone.now,
            user_id: user.id,
            user_bank_account_id: user_bank_account.id,
            cash_installments_attributes: [ { number: 1, date: Time.zone.now, price: -5_000, paid: true } ],
            category_transactions_attributes: [ { category_id: piggy_bank_category.id } ],
            entity_transactions_attributes: [ { entity_id: entity.id, price: 0, price_to_be_returned: 0 } ],
            piggy_bank_attributes: { return_date:, return_price: 5_000 }
          }
        }, headers: turbo_stream_headers
      end.to change(PiggyBank, :count).by(1).and change(CashTransaction, :count).by(2)

      source = CashTransaction.find_by!(description: "Emergency reserve", cash_transaction_type: nil)
      generated_return = source.piggy_bank.return_cash_transaction
      expect(generated_return).to have_attributes(price: 5_000, date: return_date, user_bank_account:)
      expect(generated_return.categories.pluck(:category_name)).to eq([ "PIGGY BANK RETURN" ])
      expect(generated_return.entities).to contain_exactly(entity)
    end

    it "rolls back a Piggy Bank source when its projected return is not positive" do
      piggy_bank_category = user.built_in_category("PIGGY BANK")

      expect do
        post cash_transactions_path, params: {
          cash_transaction: {
            description: "Invalid reserve",
            price: -5_000,
            date: Time.zone.now,
            user_id: user.id,
            user_bank_account_id: user_bank_account.id,
            cash_installments_attributes: [ { number: 1, date: Time.zone.now, price: -5_000, paid: true } ],
            category_transactions_attributes: [ { category_id: piggy_bank_category.id } ],
            entity_transactions_attributes: [ { entity_id: entity.id, price: 0, price_to_be_returned: 0 } ],
            piggy_bank_attributes: { return_date: 3.months.from_now, return_price: 0 }
          }
        }, headers: turbo_stream_headers
      end.not_to change(CashTransaction, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(PiggyBank.count).to eq(0)
    end

    it "attaches a new Piggy Bank source to an open grouped return" do
      piggy_bank_category = user.built_in_category("PIGGY BANK")
      original_date = 3.months.from_now.change(sec: 0)
      create_payload = lambda do |description:, price:, piggy_bank_attributes:|
        {
          cash_transaction: {
            description:,
            price:,
            date: Time.zone.now,
            user_id: user.id,
            user_bank_account_id: user_bank_account.id,
            cash_installments_attributes: [ { number: 1, date: Time.zone.now, price:, paid: true } ],
            category_transactions_attributes: [ { category_id: piggy_bank_category.id } ],
            entity_transactions_attributes: [ { entity_id: entity.id, price: 0, price_to_be_returned: 0 } ],
            piggy_bank_attributes:
          }
        }
      end

      post cash_transactions_path,
           params: create_payload.call(description: "Grouped reserve", price: -5_000, piggy_bank_attributes: { return_date: original_date, return_price: 5_000 }),
           headers: turbo_stream_headers
      grouped_return = CashTransaction.find_by!(description: "Grouped reserve", cash_transaction_type: "PiggyBank")

      get new_cash_transaction_path
      expect(response.body).to include("Grouped reserve")
      expect(response.body).to include("data-entity-id=\"#{entity.id}\"")
      expect(response.body).to include("data-return-date=\"#{grouped_return.date.iso8601}\"")

      expect do
        post cash_transactions_path,
             params: create_payload.call(
               description: "Monthly contribution",
               price: -2_000,
               piggy_bank_attributes: {
                 return_cash_transaction_id: grouped_return.id,
                 return_date: original_date + 1.month,
                 return_price: 2_000
               }
             ),
             headers: turbo_stream_headers
      end.to change(PiggyBank, :count).by(1).and change(CashTransaction, :count).by(1)

      expect(response).to have_http_status(:success)
      expect(grouped_return.reload).to have_attributes(date: original_date, price: 7_000)
      expect(grouped_return.piggy_bank_return_links.count).to eq(2)
      expect(grouped_return.cash_installments.order(:number).pluck(:price, :paid)).to eq([ [ 7_000, false ] ])
    end

    it "shows generic and detailed failure notifications when create validation fails" do
      expect do
        post cash_transactions_path,
             params: cash_transaction.params.deep_merge(cash_transaction: { description: "" }),
             headers: turbo_stream_headers
      end.not_to change(CashTransaction, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include(I18n.t("notification.not_createda", model: CashTransaction.model_name.human))
      expect(response.body).to include(CashTransaction.human_attribute_name(:description))
      expect(response.body).to include("can&#39;t be blank")
      expect(response.body).not_to include(">is invalid<")
      expect(response.body).to include('<turbo-stream action="update" target="notification">')
      expect(response.body).to include('<turbo-stream action="append" target="notification">')
    end

    it "ignores submitted exchanges_count and persists the real exchange counter cache" do
      exchange_category = user.built_in_category("EXCHANGE")
      receiver = create(:user, :random)
      receiver_entity = create(:entity, user:, entity_name: "RECEIVER", entity_user: receiver)
      create(:entity, user: receiver, entity_name: "ME", entity_user: user)

      post cash_transactions_path, params: {
        cash_transaction: {
          description: "Duplicated exchange cash transaction",
          price: 2_000,
          date: Date.new(2026, 4, 27),
          month: 4,
          year: 2026,
          user_id: user.id,
          user_bank_account_id: user_bank_account.id,
          friend_notification_intent: "loan",
          category_transactions_attributes: [
            { category_id: exchange_category.id }
          ],
          cash_installments_attributes: [
            { number: 1, date: Date.new(2026, 4, 27), month: 4, year: 2026, price: 2_000, paid: false }
          ],
          entity_transactions_attributes: [
            {
              entity_id: receiver_entity.id,
              is_payer: true,
              price: -2_000,
              price_to_be_returned: -2_000,
              exchanges_count: 1,
              exchanges_attributes: [
                { number: 1, exchange_type: "monetary", bound_type: "standalone", price: -2_000, date: Date.new(2026, 4, 28), month: 4, year: 2026 }
              ]
            }
          ]
        }
      }, headers: turbo_stream_headers

      expect(response).to have_http_status(:success)

      created_cash_transaction = user.cash_transactions.where(description: "Duplicated exchange cash transaction",
                                                              user_bank_account_id: user_bank_account.id).order(:id).last
      entity_transaction = created_cash_transaction.entity_transactions.find_by!(entity_id: receiver_entity.id)

      expect(entity_transaction.exchanges.count).to eq(1)
      expect(entity_transaction.exchanges_count).to eq(1)
    end

    it "rejects exchange cash transaction creation until the notification intent is selected" do
      exchange_category = user.built_in_category("EXCHANGE")
      receiver = create(:user, :random)
      receiver_entity = create(:entity, user:, entity_name: "RECEIVER", entity_user: receiver)
      create(:entity, user: receiver, entity_name: "ME", entity_user: user)

      expect do
        post cash_transactions_path, params: {
          cash_transaction: {
            description: "Exchange without intent",
            price: 2_000,
            date: Date.new(2026, 4, 27),
            month: 4,
            year: 2026,
            user_id: user.id,
            user_bank_account_id: user_bank_account.id,
            category_transactions_attributes: [
              { category_id: exchange_category.id }
            ],
            cash_installments_attributes: [
              { number: 1, date: Date.new(2026, 4, 27), month: 4, year: 2026, price: 2_000, paid: false }
            ],
            entity_transactions_attributes: [
              {
                entity_id: receiver_entity.id,
                is_payer: true,
                price: -2_000,
                price_to_be_returned: -2_000,
                exchanges_attributes: [
                  { number: 1, exchange_type: "monetary", bound_type: "standalone", price: -2_000, date: Date.new(2026, 4, 28), month: 4, year: 2026 }
                ]
              }
            ]
          }
        }, headers: turbo_stream_headers
      end.not_to change(CashTransaction, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include(CashTransaction.human_attribute_name(:friend_notification_intent))
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

    it "passes loan intent through to pure exchange notifications" do
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
      cash_transaction.friend_notification_intent = "loan"

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

    it "accepts indexed nested-hash params when creating a receiver borrow return from an actionable message" do
      sender = create(:user, :random)
      receiver = create(:user, :random)
      receiver_bank_account = create(:user_bank_account, :random, user: receiver, bank: create(:bank, :random))
      create(:entity, user: sender, entity_name: "RECEIVER", entity_user: receiver)
      receiver_counterpart = create(:entity, user: receiver, entity_name: "SENDER", entity_user: sender)
      conversation = Conversation.find_or_create_assistant_between!(sender, receiver)
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

      expect do
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
            reference_transactable_id: 999,
            friend_notification_intent: "reimbursement",
            source_message_id: source_message.id,
            category_transactions_attributes: {
              "0" => { category_id: receiver.built_in_category("BORROW RETURN").id }
            },
            entity_transactions_attributes: {
              "0" => {
                entity_id: receiver_counterpart.id,
                is_payer: false,
                price: 0,
                price_to_be_returned: 0,
                exchanges_count: 0,
                exchanges_attributes: {}
              }
            },
            cash_installments_attributes: {
              "0" => {
                number: 1,
                date: Date.new(2026, 3, 24),
                month: 3,
                year: 2026,
                price: 20_000
              }
            }
          }
        }, headers: turbo_stream_headers
      end.to change(receiver.main_context.cash_transactions, :count).by(1)

      created_transaction = receiver.main_context.cash_transactions.order(:id).last

      expect(response).to have_http_status(:ok)
      expect(created_transaction.categories.pluck(:category_name)).to include("BORROW RETURN")
      expect(created_transaction.reference_transactable_type).to eq("CashTransaction")
      expect(created_transaction.reference_transactable_id).to eq(999)
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

    it "keeps reimbursement update and destroy notifications resolvable without requiring a direct source-link assertion" do
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

      expect(receiver_transaction.reference_transactable).to be_present
      expect(receiver_transaction.reference_transactable).to be_a(CashTransaction)

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

    it "renders the receiver destroy action when a legacy destroy message still points to the sender source transaction" do
      sender = create(:user, :random)
      receiver = create(:user, :random)
      sender_bank_account = create(:user_bank_account, :random, user: sender, bank: create(:bank, :random))
      receiver_bank_account = create(:user_bank_account, :random, user: receiver, bank: create(:bank, :random))
      sender_entity_for_receiver = create(:entity, user: sender, entity_name: "RECEIVER", entity_user: receiver)
      receiver_entity_for_sender = create(:entity, user: receiver, entity_name: "SENDER", entity_user: sender)

      sender_transaction = create(
        :cash_transaction,
        user: sender,
        context: sender.main_context,
        user_bank_account: sender_bank_account,
        description: "Legacy destroy reimbursement",
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
            entity_id: sender_entity_for_receiver.id,
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
      sender_shared_return = create(
        :cash_transaction,
        user: sender,
        context: sender.main_context,
        user_bank_account: sender_bank_account,
        reference_transactable: sender_transaction,
        description: "Legacy destroy sender return",
        price: -20_000,
        date: Date.new(2026, 3, 24),
        month: 3,
        year: 2026,
        category_transactions_attributes: [
          { category_id: sender.built_in_category("EXCHANGE RETURN").id }
        ],
        entity_transactions_attributes: [
          {
            entity_id: sender_entity_for_receiver.id,
            is_payer: false,
            price: 0,
            price_to_be_returned: 0,
            exchanges_count: 0,
            exchanges_attributes: []
          }
        ],
        cash_installments_attributes: [
          { number: 1, price: -20_000, date: Date.new(2026, 3, 24), month: 3, year: 2026 }
        ]
      )
      receiver_transaction = create(
        :cash_transaction,
        user: receiver,
        context: receiver.main_context,
        user_bank_account: receiver_bank_account,
        reference_transactable: sender_shared_return,
        description: "Legacy destroy receiver return",
        price: -20_000,
        date: Date.new(2026, 3, 24),
        month: 3,
        year: 2026,
        category_transactions_attributes: [
          { category_id: receiver.built_in_category("BORROW RETURN").id }
        ],
        entity_transactions_attributes: [
          {
            entity_id: receiver_entity_for_sender.id,
            is_payer: false,
            price: 0,
            price_to_be_returned: 0,
            exchanges_count: 0,
            exchanges_attributes: []
          }
        ],
        cash_installments_attributes: [
          { number: 1, price: -20_000, date: Date.new(2026, 3, 24), month: 3, year: 2026 }
        ]
      )

      conversation = Conversation.find_or_create_assistant_between!(sender, receiver)
      destroy_message = conversation.messages.create!(
        user: sender,
        body: "notification:destroy",
        reference_transactable: sender_transaction,
        headers: {
          version: "message_notification_v2",
          event: {
            action: "destroy",
            receiver_first_name: receiver.first_name,
            transaction_type: "CashTransaction",
            details: { description: sender_transaction.description }
          },
          replay: nil
        }.to_json
      )

      sign_out user
      sign_in receiver

      get conversation_path(conversation, message_filter: "all")

      expect(response.body).to include(
        cash_transaction_path(id: receiver_transaction, format: :turbo_stream, message_id: destroy_message.id)
      )
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

    it "shows generic and detailed failure notifications when update validation fails" do
      cash_transaction.use_base(@existing_cash_transaction, cash_transaction_options: { description: "" })

      put cash_transaction_path(@existing_cash_transaction), params: cash_transaction.params, headers: turbo_stream_headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include(I18n.t("notification.not_updateda", model: CashTransaction.model_name.human))
      expect(response.body).to include(CashTransaction.human_attribute_name(:description))
      expect(response.body).to include("can&#39;t be blank")
      expect(response.body).not_to include(">is invalid<")
      expect(response.body).to include('<turbo-stream action="update" target="notification">')
      expect(response.body).to include('<turbo-stream action="append" target="notification">')
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
            cash_installments_attributes: [
              {
                number: 1,
                price: @existing_cash_transaction.cash_installments.first.price,
                date: @existing_cash_transaction.cash_installments.first.date,
                month: @existing_cash_transaction.cash_installments.first.month,
                year: @existing_cash_transaction.cash_installments.first.year,
                paid: @existing_cash_transaction.cash_installments.first.paid
              },
              {
                number: 2,
                price: 10_000,
                date: Time.zone.local(2026, 5, 10, 0, 0, 0),
                month: 5,
                year: 2026,
                paid: false
              },
              {
                number: 3,
                price: 10_000,
                date: Time.zone.local(2026, 6, 10, 0, 0, 0),
                month: 6,
                year: 2026,
                paid: false
              }
            ],
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
      expect(response.body).to include(%[value="#{@existing_cash_transaction.cash_installments.first.id}"])
      expect(response.body).to include(%[value="2026-05-10T00:00"])
      expect(response.body).to include(%[value="2026-06-10T00:00"])
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

    it "shows a confirmation path and then allows a paid exchange return installment price correction" do
      card_transaction = create(
        :card_transaction,
        user:,
        context: user.main_context,
        user_card: create(:user_card, :random, user:, card: create(:card, :random, bank: bank)),
        description: "Paid mirror price correction",
        date: Date.new(2026, 3, 10),
        month: 4,
        year: 2026,
        price: -2_000
      )
      card_transaction.category_transactions.destroy_all
      card_transaction.category_transactions.create!(category: user.built_in_category("EXCHANGE"))
      entity_transaction = card_transaction.entity_transactions.first
      entity_transaction.update!(price: -2_000, price_to_be_returned: -2_000, is_payer: true, exchanges_count: 2)
      first_exchange = create(:exchange, entity_transaction:, bound_type: :standalone, exchange_type: :monetary, number: 1, price: -1_000,
                                         date: Date.new(2026, 3, 20), month: 3, year: 2026)
      create(:exchange, entity_transaction:, bound_type: :standalone, exchange_type: :monetary, number: 2, price: -1_000, date: Date.new(2026, 4, 20), month: 4,
                        year: 2026)

      exchange_return = first_exchange.cash_transaction.reload
      first_installment = exchange_return.cash_installments.find_by!(number: 1)
      first_installment.update!(paid: true)
      second_installment = exchange_return.reload.cash_installments.order(:number).second

      expect(second_installment).to be_present

      base_params = {
        cash_transaction: {
          description: exchange_return.description,
          comment: exchange_return.comment,
          price: -2_500,
          date: exchange_return.date,
          month: exchange_return.month,
          year: exchange_return.year,
          user_id: user.id,
          user_bank_account_id: exchange_return.user_bank_account_id,
          category_transactions_attributes: exchange_return.category_transactions.map { |record| { id: record.id, category_id: record.category_id } },
          entity_transactions_attributes: exchange_return.entity_transactions.to_h do |record|
            [ record.id.to_s,
              { id: record.id, entity_id: record.entity_id, is_payer: record.is_payer, price: record.price, price_to_be_returned: record.price_to_be_returned,
                exchanges_attributes: {} } ]
          end,
          cash_installments_attributes: {
            "0" => {
              id: first_installment.id,
              number: 1,
              date: first_installment.date,
              month: first_installment.month,
              year: first_installment.year,
              price: -1_500,
              paid: true
            },
            "1" => {
              id: second_installment.id,
              number: 2,
              date: second_installment.date,
              month: second_installment.month,
              year: second_installment.year,
              price: -1_000,
              paid: false
            }
          }
        }
      }

      put cash_transaction_path(exchange_return), params: base_params, headers: turbo_stream_headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include(I18n.t("activerecord.errors.models.cash_transaction.attributes.base.exchange_return_price_correction_confirmation_required"))
      expect(response.body).to include(I18n.t("actions.confirm_historical_change"))

      base_params[:cash_transaction][:historical_correction_confirmation] = true

      put cash_transaction_path(exchange_return), params: base_params, headers: turbo_stream_headers

      expect(response).to have_http_status(:ok)
      expect(exchange_return.reload.cash_installments.order(:number).pluck(:price, :paid)).to eq([ [ -1_500, true ], [ -1_000, false ] ])
      expect(entity_transaction.reload.exchanges.order(:number).pluck(:price)).to eq([ -1_500, -1_000 ])
    end

    it "shows a confirmation path and then allows a normal paid amount correction" do
      locked_transaction = create_cash_transaction_with_paid_history(description: "Amount correction request")
      first_installment = locked_transaction.cash_installments.find_by!(number: 1)
      second_installment = locked_transaction.cash_installments.find_by!(number: 2)
      third_installment = locked_transaction.cash_installments.find_by!(number: 3)

      base_params = {
        cash_transaction: {
          description: locked_transaction.description,
          price: 3500,
          date: locked_transaction.date,
          month: locked_transaction.month,
          year: locked_transaction.year,
          user_id: user.id,
          user_bank_account_id: user_bank_account.id,
          category_transactions_attributes: locked_transaction.category_transactions.map { |ct| { id: ct.id, category_id: ct.category_id } },
          entity_transactions_attributes: [],
          cash_installments_attributes: {
            "0" => { id: first_installment.id, number: 1, date: first_installment.date, month: first_installment.month, year: first_installment.year, price: 1500,
                     paid: true },
            "1" => { id: second_installment.id, number: 2, date: second_installment.date, month: second_installment.month, year: second_installment.year,
                     price: 1000, paid: false },
            "2" => { id: third_installment.id, number: 3, date: third_installment.date, month: third_installment.month, year: third_installment.year, price: 1000,
                     paid: false }
          }
        }
      }

      put cash_transaction_path(locked_transaction), params: base_params, headers: turbo_stream_headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include(I18n.t("activerecord.errors.models.cash_transaction.attributes.base.paid_amount_correction_confirmation_required"))
      expect(response.body).to include(I18n.t("actions.confirm_historical_change"))

      base_params[:cash_transaction][:historical_correction_confirmation] = true

      put cash_transaction_path(locked_transaction), params: base_params, headers: turbo_stream_headers

      expect(response).to have_http_status(:ok)
      expect(locked_transaction.reload.price).to eq(3500)
      expect(locked_transaction.cash_installments.order(:number).pluck(:price)).to eq([ 1500, 1000, 1000 ])
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
              price: -3_000,
              paid: first_installment.paid
            }
          }
        }
      }, headers: turbo_stream_headers

      expect(response).to have_http_status(:ok)
      expect(exchange_return.reload.cash_installments.count).to eq(1)
      expect(exchange_return.reload.cash_installments.order(:number).pluck(:number, :price)).to eq([ [ 1, -3_000 ] ])
      expect(entity_transaction.reload.exchanges.count).to eq(1)
      expect(entity_transaction.reload.exchanges.order(:number).pluck(:number, :month, :year, :price)).to eq(
        [
          [ 1, 3, 2026, -3_000 ]
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
          friend_notification_intent: "loan",
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

      get cash_transaction_path(main_cash_transaction)
      expect(response).to have_http_status(:not_found)

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
      first_exchange = create(:exchange, entity_transaction:, bound_type: :standalone, exchange_type: :monetary, number: 1, price: -1_000,
                                         date: Date.new(2026, 4, 10), month: 4, year: 2026)
      create(:exchange, entity_transaction:, bound_type: :standalone, exchange_type: :monetary, number: 2, price: -1_000, date: Date.new(2026, 5, 10), month: 5,
                        year: 2026)
      create(:exchange, entity_transaction:, bound_type: :standalone, exchange_type: :monetary, number: 3, price: -1_000, date: Date.new(2026, 6, 10), month: 6,
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

    it "preserves paid installment state in actionable update messages when mirrored installments are restructured" do
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
        description: "Mirror source paid state",
        date: Date.new(2026, 3, 10),
        month: 4,
        year: 2026,
        price: -2_000
      )
      card_transaction.category_transactions.destroy_all
      card_transaction.category_transactions.create!(category: user.built_in_category("EXCHANGE"))
      entity_transaction = card_transaction.entity_transactions.first
      entity_transaction.update!(entity_id: receiver_entity.id, price: -2_000, price_to_be_returned: -2_000, is_payer: true, exchanges_count: 2)
      first_exchange = create(:exchange, entity_transaction:, bound_type: :standalone, exchange_type: :monetary, number: 1, price: -1_000,
                                         date: Date.new(2026, 4, 10), month: 4, year: 2026)
      create(:exchange, entity_transaction:, bound_type: :standalone, exchange_type: :monetary, number: 2, price: -1_000, date: Date.new(2026, 5, 10), month: 5,
                        year: 2026)
      exchange_return = first_exchange.cash_transaction.reload
      first_installment = exchange_return.cash_installments.find_by!(number: 1)
      first_installment.update!(paid: true, date: Time.zone.local(2026, 3, 26, 17, 0, 0))

      expect do
        patch cash_transaction_path(exchange_return), params: {
          cash_transaction: {
            description: exchange_return.description,
            comment: exchange_return.comment,
            price: -2_000,
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
                id: first_installment.id,
                number: 1,
                date: first_installment.date,
                month: 4,
                year: 2026,
                price: -1_000,
                paid: true
              },
              {
                id: exchange_return.cash_installments.find_by!(number: 2).id,
                number: 2,
                date: exchange_return.cash_installments.find_by!(number: 2).date,
                month: 5,
                year: 2026,
                price: -500,
                paid: false
              },
              {
                number: 3,
                date: Time.zone.local(2026, 6, 10, 0, 0, 0),
                month: 6,
                year: 2026,
                price: -500,
                paid: false
              }
            ]
          }
        }, headers: turbo_stream_headers
      end.to change(Message.where(body: "notification:update"), :count).by(1)

      message = Message.where(body: "notification:update").order(:id).last
      replay = JSON.parse(message.headers).fetch("replay")

      expect(replay.fetch("cash_installments_attributes")).to include(
        a_hash_including("number" => 1, "paid" => true),
        a_hash_including("number" => 2, "paid" => false),
        a_hash_including("number" => 3, "paid" => false)
      )
    end

    it "allows correcting a mirrored shared return from an actionable update even when the receiver already has paid mirrored installments" do
      receiver = create(:user, :random)
      sender_entity = create(:entity, user:, entity_name: receiver.first_name.upcase, entity_user: receiver)
      receiver_counterpart = create(:entity, user: receiver, entity_name: user.first_name.upcase, entity_user: user)
      user_card = create(:user_card, :random, user:, card: create(:card, :random, bank: bank))
      receiver_bank_account = create(:user_bank_account, :random, user: receiver, bank: create(:bank, :random))
      card_transaction = create(
        :card_transaction,
        user:,
        context: user.main_context,
        user_card:,
        description: "Mirror correction source",
        date: Time.zone.local(2026, 3, 30, 13, 4, 0),
        month: 4,
        year: 2026,
        price: -12_000
      )
      card_transaction.category_transactions.destroy_all
      card_transaction.category_transactions.create!(category: user.built_in_category("EXCHANGE"))
      entity_transaction = card_transaction.entity_transactions.first
      entity_transaction.update!(entity_id: sender_entity.id, price: -12_000, price_to_be_returned: -12_000, is_payer: true, exchanges_count: 2)
      first_exchange = create(:exchange, entity_transaction:, bound_type: :standalone, exchange_type: :monetary, number: 1, price: -6_000,
                                         date: Time.zone.local(2026, 4, 10, 0, 0, 0), month: 4, year: 2026)
      create(:exchange, entity_transaction:, bound_type: :standalone, exchange_type: :monetary, number: 2, price: -6_000,
                        date: Time.zone.local(2026, 5, 10, 0, 0, 0), month: 5, year: 2026)

      sender_return = first_exchange.cash_transaction.reload
      sender_return.cash_installments.find_by!(number: 1).update!(paid: true, date: Time.zone.local(2026, 3, 30, 13, 4, 0))
      sender_return.cash_installments.find_by!(number: 2).update!(paid: true, date: Time.zone.local(2026, 3, 30, 14, 0, 0))
      Logic::Manipulation::CashInstallment.new(sender_return.cash_installments.find_by!(number: 1)).split_installment(Time.zone.local(2026, 4, 30, 13, 4, 0), -4_000)
      sender_return.reload.update_columns(price: -12_000, starting_price: -12_000, cash_installments_count: 3)

      receiver_return = create(
        :cash_transaction,
        user: receiver,
        context: receiver.main_context,
        user_bank_account: receiver_bank_account,
        reference_transactable: sender_return,
        description: sender_return.description,
        date: Time.zone.local(2026, 4, 10, 0, 0, 0),
        month: 4,
        year: 2026,
        price: -12_000,
        category_transactions_attributes: [
          { category_id: receiver.built_in_category("BORROW RETURN").id }
        ],
        entity_transactions_attributes: [
          { entity_id: receiver_counterpart.id, is_payer: false, price: 0, price_to_be_returned: 0 }
        ],
        cash_installments_attributes: [
          { number: 1, date: Time.zone.local(2026, 4, 10, 0, 0, 0), month: 4, year: 2026, price: -6_000, paid: false },
          { number: 2, date: Time.zone.local(2026, 5, 10, 0, 0, 0), month: 5, year: 2026, price: -6_000, paid: false }
        ]
      )
      receiver_return.cash_installments.destroy_all
      receiver_return.cash_installments.create!(number: 1, date: Time.zone.local(2026, 4, 10, 0, 0, 0), month: 4, year: 2026, price: -6_000, paid: true)
      receiver_return.cash_installments.create!(number: 2, date: Time.zone.local(2026, 5, 10, 0, 0, 0), month: 5, year: 2026, price: -6_000, paid: true)
      receiver_return.update_columns(cash_installments_count: 2, price: -12_000, starting_price: -12_000)

      conversation = Conversation.find_or_create_assistant_between!(user, receiver)
      update_message = conversation.messages.create!(
        user: user,
        reference_transactable: card_transaction,
        body: "notification:update",
        headers: {
          version: "message_notification_v2",
          event: {
            action: "update",
            receiver_first_name: receiver.first_name,
            transaction_type: "CardTransaction",
            details: { description: receiver_return.description }
          },
          replay: {
            id: card_transaction.id,
            type: "CardTransaction",
            description: receiver_return.description,
            price: -12_000,
            date: Time.zone.local(2026, 3, 30, 13, 4, 0).iso8601,
            month: 3,
            year: 2026,
            category_ids: [ receiver.built_in_category("BORROW RETURN").id ],
            entity_ids: [ receiver_counterpart.id ],
            cash_installments_attributes: [
              { number: 1, date: Time.zone.local(2026, 3, 30, 13, 4, 0).iso8601, month: 3, year: 2026, price: -4_000, paid: true },
              { number: 2, date: Time.zone.local(2026, 3, 30, 14, 0, 0).iso8601, month: 3, year: 2026, price: -4_000, paid: true },
              { number: 3, date: Time.zone.local(2026, 4, 30, 13, 4, 0).iso8601, month: 4, year: 2026, price: -4_000, paid: false }
            ],
            entity_transactions_attributes: [
              {
                id: receiver_return.entity_transactions.first.id,
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

      put cash_transaction_path(receiver_return), params: {
        cash_transaction: {
          description: receiver_return.description,
          price: -12_000,
          date: Time.zone.local(2026, 3, 30, 13, 4, 0),
          month: 3,
          year: 2026,
          user_id: receiver.id,
          user_bank_account_id: receiver_bank_account.id,
          reference_transactable_type: "CardTransaction",
          reference_transactable_id: card_transaction.id,
          source_message_id: update_message.id,
          category_transactions_attributes: receiver_return.category_transactions.map { |ct| { id: ct.id, category_id: ct.category_id } },
          entity_transactions_attributes: [
            {
              id: receiver_return.entity_transactions.first.id,
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
              id: receiver_return.cash_installments.find_by!(number: 1).id,
              number: 1,
              date: Time.zone.local(2026, 3, 30, 13, 4, 0),
              month: 3,
              year: 2026,
              price: -4_000,
              paid: true
            },
            {
              id: receiver_return.cash_installments.find_by!(number: 2).id,
              number: 2,
              date: Time.zone.local(2026, 3, 30, 14, 0, 0),
              month: 3,
              year: 2026,
              price: -4_000,
              paid: true
            },
            {
              number: 3,
              date: Time.zone.local(2026, 4, 30, 13, 4, 0),
              month: 4,
              year: 2026,
              price: -4_000,
              paid: false
            }
          ]
        }
      }, headers: turbo_stream_headers

      expect(response).to have_http_status(:ok)
      expect(receiver_return.reload.reference_transactable).to eq(sender_return)
      expect(receiver_return.reload.cash_installments.order(:number).pluck(:price, :paid)).to eq([ [ -4_000, true ], [ -4_000, true ], [ -4_000, false ] ])
    end

    it "allows applying a partial-pay structural update when only the first mirrored installment was previously paid" do
      receiver = create(:user, :random)
      sender_entity = create(:entity, user:, entity_name: receiver.first_name.upcase, entity_user: receiver)
      receiver_counterpart = create(:entity, user: receiver, entity_name: user.first_name.upcase, entity_user: user)
      user_card = create(:user_card, :random, user:, card: create(:card, :random, bank: bank))
      receiver_bank_account = create(:user_bank_account, :random, user: receiver, bank: create(:bank, :random))
      card_transaction = create(
        :card_transaction,
        user:,
        context: user.main_context,
        user_card:,
        description: "Mirror partial pay source",
        date: Time.zone.local(2026, 3, 30, 13, 4, 0),
        month: 4,
        year: 2026,
        price: -6_000
      )
      card_transaction.category_transactions.destroy_all
      card_transaction.category_transactions.create!(category: user.built_in_category("EXCHANGE"))
      entity_transaction = card_transaction.entity_transactions.first
      entity_transaction.update!(entity_id: sender_entity.id, price: -6_000, price_to_be_returned: -6_000, is_payer: true, exchanges_count: 2)
      first_exchange = create(:exchange, entity_transaction:, bound_type: :standalone, exchange_type: :monetary, number: 1, price: -3_000,
                                         date: Time.zone.local(2026, 4, 10, 0, 0, 0), month: 4, year: 2026)
      create(:exchange, entity_transaction:, bound_type: :standalone, exchange_type: :monetary, number: 2, price: -3_000,
                        date: Time.zone.local(2026, 5, 10, 0, 0, 0), month: 5, year: 2026)

      sender_return = first_exchange.cash_transaction.reload
      sender_return.cash_installments.find_by!(number: 1).update!(paid: true, date: Time.zone.local(2026, 3, 30, 13, 4, 0))
      sender_return.cash_installments.find_by!(number: 2).update!(paid: true, date: Time.zone.local(2026, 3, 30, 14, 0, 0))
      Logic::Manipulation::CashInstallment.new(sender_return.cash_installments.find_by!(number: 2)).split_installment(Time.zone.local(2026, 4, 30, 13, 4, 0), -1_500)
      sender_return.cash_installments.find_by!(number: 2).update!(price: -1_500)
      sender_return.reload.update_columns(price: -6_000, starting_price: -6_000, cash_installments_count: 3)

      receiver_return = create(
        :cash_transaction,
        user: receiver,
        context: receiver.main_context,
        user_bank_account: receiver_bank_account,
        reference_transactable: sender_return,
        description: sender_return.description,
        date: Time.zone.local(2026, 4, 10, 0, 0, 0),
        month: 4,
        year: 2026,
        price: -6_000,
        category_transactions_attributes: [
          { category_id: receiver.built_in_category("BORROW RETURN").id }
        ],
        entity_transactions_attributes: [
          { entity_id: receiver_counterpart.id, is_payer: false, price: 0, price_to_be_returned: 0 }
        ],
        cash_installments_attributes: [
          { number: 1, date: Time.zone.local(2026, 4, 10, 0, 0, 0), month: 4, year: 2026, price: -3_000, paid: false },
          { number: 2, date: Time.zone.local(2026, 5, 10, 0, 0, 0), month: 5, year: 2026, price: -3_000, paid: false }
        ]
      )
      receiver_return.cash_installments.destroy_all
      receiver_return.cash_installments.create!(number: 1, date: Time.zone.local(2026, 3, 30, 13, 4, 0), month: 3, year: 2026, price: -3_000, paid: true)
      receiver_return.cash_installments.create!(number: 2, date: Time.zone.local(2026, 5, 10, 0, 0, 0), month: 5, year: 2026, price: -3_000, paid: false)
      receiver_return.update_columns(cash_installments_count: 2, price: -6_000, starting_price: -6_000)

      conversation = Conversation.find_or_create_assistant_between!(user, receiver)
      update_message = conversation.messages.create!(
        user: user,
        reference_transactable: card_transaction,
        body: "notification:update",
        headers: {
          version: "message_notification_v2",
          event: {
            action: "update",
            receiver_first_name: receiver.first_name,
            transaction_type: "CardTransaction",
            details: { description: receiver_return.description }
          },
          replay: {
            id: card_transaction.id,
            type: "CardTransaction",
            description: receiver_return.description,
            price: -6_000,
            date: Time.zone.local(2026, 3, 30, 13, 4, 0).iso8601,
            month: 3,
            year: 2026,
            category_ids: [ receiver.built_in_category("BORROW RETURN").id ],
            entity_ids: [ receiver_counterpart.id ],
            cash_installments_attributes: [
              { number: 1, date: Time.zone.local(2026, 3, 30, 13, 4, 0).iso8601, month: 3, year: 2026, price: -3_000, paid: true },
              { number: 2, date: Time.zone.local(2026, 3, 30, 14, 0, 0).iso8601, month: 3, year: 2026, price: -1_500, paid: true },
              { number: 3, date: Time.zone.local(2026, 4, 30, 13, 4, 0).iso8601, month: 4, year: 2026, price: -1_500, paid: false }
            ],
            entity_transactions_attributes: [
              {
                id: receiver_return.entity_transactions.first.id,
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

      put cash_transaction_path(receiver_return), params: {
        cash_transaction: {
          description: receiver_return.description,
          price: -6_000,
          date: Time.zone.local(2026, 3, 30, 13, 4, 0),
          month: 3,
          year: 2026,
          user_id: receiver.id,
          user_bank_account_id: receiver_bank_account.id,
          reference_transactable_type: "CardTransaction",
          reference_transactable_id: card_transaction.id,
          source_message_id: update_message.id,
          category_transactions_attributes: receiver_return.category_transactions.map { |ct| { id: ct.id, category_id: ct.category_id } },
          entity_transactions_attributes: [
            {
              id: receiver_return.entity_transactions.first.id,
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
              id: receiver_return.cash_installments.find_by!(number: 1).id,
              number: 1,
              date: Time.zone.local(2026, 3, 30, 13, 4, 0),
              month: 3,
              year: 2026,
              price: -3_000,
              paid: true
            },
            {
              id: receiver_return.cash_installments.find_by!(number: 2).id,
              number: 2,
              date: Time.zone.local(2026, 3, 30, 14, 0, 0),
              month: 3,
              year: 2026,
              price: -1_500,
              paid: true
            },
            {
              number: 3,
              date: Time.zone.local(2026, 4, 30, 13, 4, 0),
              month: 4,
              year: 2026,
              price: -1_500,
              paid: false
            }
          ]
        }
      }, headers: turbo_stream_headers

      expect(response).to have_http_status(:ok)
      expect(receiver_return.reload.cash_installments.order(:number).pluck(:price, :paid)).to eq([ [ -3_000, true ], [ -1_500, true ], [ -1_500, false ] ])
    end

    it "normalizes the receiver shared return reference away from the canonical card transaction when opening an actionable update" do
      receiver = create(:user, :random)
      sender_entity = create(:entity, user:, entity_name: receiver.first_name.upcase, entity_user: receiver)
      receiver_counterpart = create(:entity, user: receiver, entity_name: user.first_name.upcase, entity_user: user)
      user_card = create(:user_card, :random, user:, card: create(:card, :random, bank: bank))
      receiver_bank_account = create(:user_bank_account, :random, user: receiver, bank: create(:bank, :random))
      card_transaction = create(
        :card_transaction,
        user:,
        context: user.main_context,
        user_card:,
        description: "Mirror reference normalization source",
        date: Time.zone.local(2026, 3, 30, 13, 4, 0),
        month: 4,
        year: 2026,
        price: -2_000
      )
      card_transaction.category_transactions.destroy_all
      card_transaction.category_transactions.create!(category: user.built_in_category("EXCHANGE"))
      entity_transaction = card_transaction.entity_transactions.first
      entity_transaction.update!(entity_id: sender_entity.id, price: -2_000, price_to_be_returned: -2_000, is_payer: true, exchanges_count: 2)
      first_exchange = create(:exchange, entity_transaction:, bound_type: :standalone, exchange_type: :monetary, number: 1, price: -1_000,
                                         date: Time.zone.local(2026, 4, 10, 0, 0, 0), month: 4, year: 2026)
      create(:exchange, entity_transaction:, bound_type: :standalone, exchange_type: :monetary, number: 2, price: -1_000,
                        date: Time.zone.local(2026, 5, 10, 0, 0, 0), month: 5, year: 2026)

      sender_return = first_exchange.cash_transaction.reload
      receiver_return = create(
        :cash_transaction,
        user: receiver,
        context: receiver.main_context,
        user_bank_account: receiver_bank_account,
        reference_transactable: card_transaction,
        description: sender_return.description,
        date: Time.zone.local(2026, 4, 10, 0, 0, 0),
        month: 4,
        year: 2026,
        price: -2_000,
        category_transactions_attributes: [
          { category_id: receiver.built_in_category("BORROW RETURN").id }
        ],
        entity_transactions_attributes: [
          { entity_id: receiver_counterpart.id, is_payer: false, price: 0, price_to_be_returned: 0 }
        ],
        cash_installments_attributes: [
          { number: 1, date: Time.zone.local(2026, 4, 10, 0, 0, 0), month: 4, year: 2026, price: -1_000, paid: false },
          { number: 2, date: Time.zone.local(2026, 5, 10, 0, 0, 0), month: 5, year: 2026, price: -1_000, paid: false }
        ]
      )
      conversation = Conversation.find_or_create_assistant_between!(user, receiver)
      update_message = conversation.messages.create!(
        user: user,
        reference_transactable: card_transaction,
        body: "notification:update",
        headers: {
          version: "message_notification_v2",
          event: {
            action: "update",
            receiver_first_name: receiver.first_name,
            transaction_type: "CardTransaction",
            details: { description: receiver_return.description }
          },
          replay: {
            id: card_transaction.id,
            type: "CardTransaction",
            description: receiver_return.description,
            price: -2_000,
            date: Time.zone.local(2026, 3, 30, 13, 4, 0).iso8601,
            month: 3,
            year: 2026,
            category_ids: [ receiver.built_in_category("BORROW RETURN").id ],
            entity_ids: [ receiver_counterpart.id ],
            cash_installments_attributes: [
              { number: 1, date: Time.zone.local(2026, 3, 30, 13, 4, 0).iso8601, month: 3, year: 2026, price: -1_000, paid: true },
              { number: 2, date: Time.zone.local(2026, 4, 10, 0, 0, 0).iso8601, month: 4, year: 2026, price: -1_000, paid: false }
            ],
            entity_transactions_attributes: [
              {
                id: receiver_return.entity_transactions.first.id,
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

      get edit_cash_transaction_path(receiver_return, cash_transaction: { source_message_id: update_message.id }), headers: turbo_stream_headers
      document = Nokogiri::HTML.fragment(response.body)
      reference_type_input = document.at_css('input[name="cash_transaction[reference_transactable_type]"]')
      reference_id_input = document.at_css('input[name="cash_transaction[reference_transactable_id]"]')

      expect(response).to have_http_status(:ok)
      expect(reference_type_input).to be_present
      expect(reference_type_input["value"]).to eq("CashTransaction")
      expect(reference_id_input).to be_present
      expect(reference_id_input["value"]).to eq(sender_return.id.to_s)
    end

    it "renders replayed exchange rows from an actionable update on a persisted receiver exchange" do
      receiver = create(:user, :random)
      sender_entity = create(:entity, user:, entity_name: receiver.first_name.upcase, entity_user: receiver)
      receiver_counterpart = create(:entity, user: receiver, entity_name: user.first_name.upcase, entity_user: user)
      sender_bank_account = create(:user_bank_account, :random, user:)
      receiver_bank_account = create(:user_bank_account, :random, user: receiver)

      sender_exchange = create(
        :cash_transaction,
        user:,
        context: user.main_context,
        user_bank_account: sender_bank_account,
        description: "Actionable exchange replay source",
        date: Time.zone.local(2026, 6, 26, 13, 48, 0),
        month: 6,
        year: 2026,
        price: -70_000,
        friend_notification_intent: "loan",
        category_transactions_attributes: [
          { category_id: user.built_in_category("EXCHANGE").id }
        ],
        entity_transactions_attributes: [
          {
            entity_id: sender_entity.id,
            is_payer: true,
            price: 70_000,
            price_to_be_returned: 70_000,
            exchanges_count: 1,
            exchanges_attributes: [
              { number: 1, price: 70_000, date: Time.zone.local(2026, 6, 27, 13, 48, 0), month: 6, year: 2026 }
            ]
          }
        ],
        cash_installments_attributes: [
          { number: 1, price: -70_000, date: Time.zone.local(2026, 6, 26, 13, 48, 0), month: 6, year: 2026, paid: true }
        ]
      )
      sender_return = sender_exchange.first_reference_descendant

      receiver_exchange = create(
        :cash_transaction,
        user: receiver,
        context: receiver.main_context,
        user_bank_account: receiver_bank_account,
        reference_transactable: sender_return,
        description: sender_exchange.description,
        date: Time.zone.local(2026, 6, 26, 13, 48, 0),
        month: 6,
        year: 2026,
        price: 70_000,
        friend_notification_intent: "loan",
        category_transactions_attributes: [
          { category_id: receiver.built_in_category("EXCHANGE").id }
        ],
        entity_transactions_attributes: [
          {
            entity_id: receiver_counterpart.id,
            is_payer: true,
            price: -70_000,
            price_to_be_returned: -70_000,
            exchanges_count: 1,
            exchanges_attributes: [
              { number: 1, price: -70_000, date: Time.zone.local(2026, 6, 27, 0, 0, 0), month: 6, year: 2026 }
            ]
          }
        ],
        cash_installments_attributes: [
          { number: 1, price: 70_000, date: Time.zone.local(2026, 6, 26, 13, 48, 0), month: 6, year: 2026, paid: true }
        ]
      )

      conversation = Conversation.find_or_create_assistant_between!(user, receiver)
      update_message = conversation.messages.create!(
        user: user,
        reference_transactable: sender_exchange,
        body: "notification:update",
        headers: {
          version: "message_notification_v2",
          event: {
            action: "update",
            receiver_first_name: receiver.first_name,
            transaction_type: "CashTransaction",
            details: { description: receiver_exchange.description }
          },
          replay: {
            id: sender_exchange.id,
            type: "CashTransaction",
            description: receiver_exchange.description,
            price: receiver_exchange.price,
            date: receiver_exchange.date.iso8601,
            month: receiver_exchange.month,
            year: receiver_exchange.year,
            category_ids: [ receiver.built_in_category("EXCHANGE").id ],
            cash_installments_attributes: [
              { number: 1, date: receiver_exchange.cash_installments.first.date.iso8601, month: 6, year: 2026, price: 70_000, paid: true }
            ],
            entity_transactions_attributes: [
              {
                id: receiver_exchange.entity_transactions.first.id,
                entity_id: receiver_counterpart.id,
                is_payer: true,
                price: -70_000,
                price_to_be_returned: -70_000,
                exchanges_count: 3,
                exchanges_attributes: [
                  { number: 1, date: Time.zone.local(2026, 6, 26, 13, 48, 0).iso8601, month: 6, year: 2026, price: -20_000 },
                  { number: 2, date: Time.zone.local(2026, 6, 27, 13, 48, 0).iso8601, month: 6, year: 2026, price: -25_000 },
                  { number: 3, date: Time.zone.local(2026, 7, 27, 13, 48, 0).iso8601, month: 7, year: 2026, price: -25_000 }
                ]
              }
            ]
          }
        }.to_json
      )

      sign_out user
      sign_in receiver

      get edit_cash_transaction_path(receiver_exchange, cash_transaction: { source_message_id: update_message.id }), headers: turbo_stream_headers
      document = Nokogiri::HTML.fragment(response.body)
      rendered_exchange_numbers = document.css("input.exchange_number").reject do |input|
        input["name"].to_s.include?("NEW_NESTED_RECORD")
      end

      expect(response).to have_http_status(:ok)
      expect(rendered_exchange_numbers.count).to eq(3)
      expect(rendered_exchange_numbers.map { |input| input["value"] }).to eq(%w[1 2 3])
    end

    it "applies replayed exchange rows onto the receiver exchange when correcting a shared loan exchange" do
      receiver = create(:user, :random)
      sender_entity = create(:entity, user:, entity_name: receiver.first_name.upcase, entity_user: receiver)
      receiver_counterpart = create(:entity, user: receiver, entity_name: user.first_name.upcase, entity_user: user)
      sender_bank_account = create(:user_bank_account, :random, user:)
      receiver_bank_account = create(:user_bank_account, :random, user: receiver)

      sender_exchange = create(
        :cash_transaction,
        user:,
        context: user.main_context,
        user_bank_account: sender_bank_account,
        description: "Receiver exchange paid replay source",
        date: Time.zone.local(2026, 6, 26, 12, 0, 0),
        month: 6,
        year: 2026,
        price: -20_000,
        friend_notification_intent: "loan",
        category_transactions_attributes: [
          { category_id: user.built_in_category("EXCHANGE").id }
        ],
        entity_transactions_attributes: [
          {
            entity_id: sender_entity.id,
            is_payer: true,
            price: 20_000,
            price_to_be_returned: 20_000,
            exchanges_count: 2,
            exchanges_attributes: [
              { number: 1, price: 12_000, date: Time.zone.local(2026, 6, 26, 15, 0, 0), month: 6, year: 2026 },
              { number: 2, price: 8_000, date: Time.zone.local(2026, 6, 27, 0, 0, 0), month: 6, year: 2026 }
            ]
          }
        ],
        cash_installments_attributes: [
          { number: 1, price: -20_000, date: Time.zone.local(2026, 6, 26, 12, 0, 0), month: 6, year: 2026, paid: true }
        ]
      )
      sender_return = create(
        :cash_transaction,
        user:,
        context: user.main_context,
        user_bank_account: sender_bank_account,
        reference_transactable: sender_exchange,
        description: sender_exchange.description,
        date: Time.zone.local(2026, 6, 27, 0, 0, 0),
        month: 6,
        year: 2026,
        price: 20_000,
        category_transactions_attributes: [
          { category_id: user.built_in_category("EXCHANGE RETURN").id }
        ],
        entity_transactions_attributes: [
          { entity_id: sender_entity.id, is_payer: false, price: 0, price_to_be_returned: 0 }
        ],
        cash_installments_attributes: [
          { number: 1, price: 12_000, date: Time.zone.local(2026, 6, 26, 15, 0, 0), month: 6, year: 2026, paid: true },
          { number: 2, price: 8_000, date: Time.zone.local(2026, 6, 27, 0, 0, 0), month: 6, year: 2026, paid: false }
        ]
      )
      sender_exchange.entity_transactions.first.exchanges.update_all(cash_transaction_id: sender_return.id)

      receiver_exchange = create(
        :cash_transaction,
        user: receiver,
        context: receiver.main_context,
        user_bank_account: receiver_bank_account,
        reference_transactable: sender_return,
        description: sender_exchange.description,
        date: Time.zone.local(2026, 6, 26, 12, 0, 0),
        month: 6,
        year: 2026,
        price: 20_000,
        friend_notification_intent: "loan",
        category_transactions_attributes: [
          { category_id: receiver.built_in_category("EXCHANGE").id }
        ],
        entity_transactions_attributes: [
          {
            entity_id: receiver_counterpart.id,
            is_payer: true,
            price: -20_000,
            price_to_be_returned: -20_000,
            exchanges_count: 1,
            exchanges_attributes: [
              { number: 1, price: -20_000, date: Time.zone.local(2026, 6, 27, 0, 0, 0), month: 6, year: 2026 }
            ]
          }
        ],
        cash_installments_attributes: [
          { number: 1, price: 20_000, date: Time.zone.local(2026, 6, 26, 12, 0, 0), month: 6, year: 2026, paid: true }
        ]
      )
      receiver_return = create(
        :cash_transaction,
        user: receiver,
        context: receiver.main_context,
        user_bank_account: receiver_bank_account,
        reference_transactable: receiver_exchange,
        description: sender_exchange.description,
        date: Time.zone.local(2026, 6, 27, 0, 0, 0),
        month: 6,
        year: 2026,
        price: -20_000,
        category_transactions_attributes: [
          { category_id: receiver.built_in_category("EXCHANGE RETURN").id }
        ],
        entity_transactions_attributes: [
          { entity_id: receiver_counterpart.id, is_payer: false, price: 0, price_to_be_returned: 0 }
        ],
        cash_installments_attributes: [
          { number: 1, price: -20_000, date: Time.zone.local(2026, 6, 27, 0, 0, 0), month: 6, year: 2026, paid: false }
        ]
      )
      receiver_exchange.entity_transactions.first.exchanges.update_all(cash_transaction_id: receiver_return.id)

      conversation = Conversation.find_or_create_assistant_between!(user, receiver)
      update_message = conversation.messages.create!(
        user: user,
        reference_transactable: sender_exchange,
        body: "notification:update",
        headers: {
          version: "message_notification_v2",
          event: {
            action: "update",
            receiver_first_name: receiver.first_name,
            transaction_type: "CashTransaction",
            details: { description: receiver_exchange.description }
          },
          replay: {
            id: sender_exchange.id,
            type: "CashTransaction",
            intent: "loan",
            description: receiver_exchange.description,
            price: receiver_exchange.price,
            date: receiver_exchange.date.iso8601,
            month: receiver_exchange.month,
            year: receiver_exchange.year,
            category_ids: [ receiver.built_in_category("EXCHANGE").id ],
            entity_ids: [ receiver_counterpart.id ],
            entity_transactions_attributes: [
              {
                id: receiver_exchange.entity_transactions.first.id,
                entity_id: receiver_counterpart.id,
                is_payer: true,
                price: -20_000,
                price_to_be_returned: -20_000,
                exchanges_count: 2,
                exchanges_attributes: [
                  { id: receiver_exchange.entity_transactions.first.exchanges.first.id, number: 1, date: Time.zone.local(2026, 6, 26, 15, 0, 0).iso8601, month: 6,
                    year: 2026, price: -12_000, paid: true },
                  { number: 2, date: Time.zone.local(2026, 6, 27, 0, 0, 0).iso8601, month: 6, year: 2026, price: -8_000, paid: false }
                ]
              }
            ]
          }
        }.to_json
      )

      sign_out user
      sign_in receiver

      put cash_transaction_path(receiver_exchange), params: {
        cash_transaction: {
          description: receiver_exchange.description,
          price: 20_000,
          date: Time.zone.local(2026, 6, 26, 12, 0, 0),
          month: 6,
          year: 2026,
          user_id: receiver.id,
          user_bank_account_id: receiver_bank_account.id,
          reference_transactable_type: "CashTransaction",
          reference_transactable_id: sender_exchange.id,
          source_message_id: update_message.id,
          category_transactions_attributes: receiver_exchange.category_transactions.map { |ct| { id: ct.id, category_id: ct.category_id } },
          entity_transactions_attributes: [
            {
              id: receiver_exchange.entity_transactions.first.id,
              entity_id: receiver_counterpart.id,
              is_payer: true,
              price: -20_000,
              price_to_be_returned: -20_000,
              exchanges_count: 2,
              exchanges_attributes: [
                {
                  id: receiver_exchange.entity_transactions.first.exchanges.first.id,
                  number: 1,
                  date: Time.zone.local(2026, 6, 26, 15, 0, 0),
                  month: 6,
                  year: 2026,
                  price: -12_000,
                  paid: true
                },
                {
                  number: 2,
                  date: Time.zone.local(2026, 6, 27, 0, 0, 0),
                  month: 6,
                  year: 2026,
                  price: -8_000,
                  paid: false
                }
              ]
            }
          ],
          cash_installments_attributes: [
            {
              id: receiver_exchange.cash_installments.first.id,
              number: 1,
              date: Time.zone.local(2026, 6, 26, 12, 0, 0),
              month: 6,
              year: 2026,
              price: 20_000,
              paid: true
            }
          ]
        }
      }, headers: turbo_stream_headers

      expect(response).to have_http_status(:ok)
      expect(receiver_exchange.reload.entity_transactions.first.exchanges.order(:number).pluck(:price)).to eq([ -12_000, -8_000 ])
    end

    it "preserves the sender shared-return parent and does not emit an echo update when applying a receiver-originated structural correction" do
      receiver = create(:user, :random)
      sender_entity = create(:entity, user:, entity_name: receiver.first_name.upcase, entity_user: receiver)
      create(:entity, user: receiver, entity_name: user.first_name.upcase, entity_user: user)
      user_card = create(:user_card, :random, user:, card: create(:card, :random, bank: bank))

      card_transaction = create(
        :card_transaction,
        user:,
        context: user.main_context,
        user_card:,
        description: "Receiver-originated correction source",
        date: Time.zone.local(2026, 3, 30, 13, 4, 0),
        month: 4,
        year: 2026,
        price: -6_000
      )
      card_transaction.category_transactions.destroy_all
      card_transaction.category_transactions.create!(category: user.built_in_category("EXCHANGE"))
      entity_transaction = card_transaction.entity_transactions.first
      entity_transaction.update!(entity_id: sender_entity.id, price: -6_000, price_to_be_returned: -6_000, is_payer: true, exchanges_count: 2)
      first_exchange = create(
        :exchange,
        entity_transaction:,
        bound_type: :standalone,
        exchange_type: :monetary,
        number: 1,
        price: -3_000,
        date: Time.zone.local(2026, 4, 10, 0, 0, 0),
        month: 4,
        year: 2026
      )
      create(
        :exchange,
        entity_transaction:,
        bound_type: :standalone,
        exchange_type: :monetary,
        number: 2,
        price: -3_000,
        date: Time.zone.local(2026, 5, 10, 0, 0, 0),
        month: 5,
        year: 2026
      )

      sender_return = first_exchange.cash_transaction.reload
      receiver_bank_account = create(:user_bank_account, :random, user: receiver, bank: create(:bank, :random))
      receiver_return = create(
        :cash_transaction,
        user: receiver,
        context: receiver.main_context,
        user_bank_account: receiver_bank_account,
        reference_transactable: sender_return,
        description: sender_return.description,
        date: Time.zone.local(2026, 4, 10, 0, 0, 0),
        month: 4,
        year: 2026,
        price: -6_000,
        category_transactions_attributes: [
          { category_id: receiver.built_in_category("BORROW RETURN").id }
        ],
        entity_transactions_attributes: [
          { entity_id: receiver.entities.that_are_users.find_by!(entity_user: user).id, is_payer: false, price: 0, price_to_be_returned: 0 }
        ],
        cash_installments_attributes: [
          { number: 1, date: Time.zone.local(2026, 4, 10, 0, 0, 0), month: 4, year: 2026, price: -3_000, paid: false },
          { number: 2, date: Time.zone.local(2026, 5, 10, 0, 0, 0), month: 5, year: 2026, price: -3_000, paid: false }
        ]
      )

      conversation = Conversation.find_or_create_assistant_between!(receiver, user)
      source_message = conversation.messages.create!(
        user: receiver,
        reference_transactable: sender_return,
        body: "notification:update",
        headers: {
          version: "message_notification_v2",
          event: {
            action: "update",
            receiver_first_name: user.first_name,
            transaction_type: "CashTransaction",
            details: { description: sender_return.description }
          },
          replay: {
            id: sender_return.id,
            type: "CashTransaction",
            description: sender_return.description,
            price: -6_000,
            date: Time.zone.local(2026, 3, 30, 13, 4, 0).iso8601,
            month: 3,
            year: 2026,
            category_ids: [ user.built_in_category("EXCHANGE RETURN").id ],
            entity_ids: [ sender_entity.id ],
            cash_installments_attributes: [
              { number: 1, date: Time.zone.local(2026, 3, 30, 13, 4, 0).iso8601, month: 3, year: 2026, price: -3_000, paid: true },
              { number: 2, date: Time.zone.local(2026, 4, 30, 13, 4, 0).iso8601, month: 4, year: 2026, price: -1_500, paid: false },
              { number: 3, date: Time.zone.local(2026, 5, 30, 13, 4, 0).iso8601, month: 5, year: 2026, price: -1_500, paid: false }
            ],
            entity_transactions_attributes: [
              {
                id: sender_return.entity_transactions.first.id,
                entity_id: sender_entity.id,
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

      expect do
        put cash_transaction_path(sender_return), params: {
          cash_transaction: {
            description: sender_return.description,
            price: -6_000,
            date: Time.zone.local(2026, 3, 30, 13, 4, 0),
            month: 3,
            year: 2026,
            user_id: user.id,
            user_bank_account_id: sender_return.user_bank_account_id,
            reference_transactable_type: "CashTransaction",
            reference_transactable_id: sender_return.id,
            source_message_id: source_message.id,
            category_transactions_attributes: sender_return.category_transactions.map { |ct| { id: ct.id, category_id: ct.category_id } },
            entity_transactions_attributes: [
              {
                id: sender_return.entity_transactions.first.id,
                entity_id: sender_entity.id,
                is_payer: false,
                price: 0,
                price_to_be_returned: 0,
                exchanges_count: 0,
                exchanges_attributes: []
              }
            ],
            cash_installments_attributes: [
              {
                id: sender_return.cash_installments.find_by!(number: 1).id,
                number: 1,
                date: Time.zone.local(2026, 3, 30, 13, 4, 0),
                month: 3,
                year: 2026,
                price: -3_000,
                paid: true
              },
              {
                id: sender_return.cash_installments.find_by!(number: 2).id,
                number: 2,
                date: Time.zone.local(2026, 4, 30, 13, 4, 0),
                month: 4,
                year: 2026,
                price: -1_500,
                paid: false
              },
              {
                number: 3,
                date: Time.zone.local(2026, 5, 30, 13, 4, 0),
                month: 5,
                year: 2026,
                price: -1_500,
                paid: false
              }
            ]
          }
        }, headers: turbo_stream_headers
      end.not_to change(Message.where(body: "notification:update"), :count)

      expect(response).to have_http_status(:ok)
      expect(sender_return.reload.reference_transactable).to eq(card_transaction)
      expect(source_message.reload.applied_at).to be_present
      expect(receiver_return.reload.reference_transactable).to eq(sender_return)
    end

    it "creates an actionable update when a receiver borrow return is restructured manually" do
      receiver = create(:user, :random)
      sender_entity = create(:entity, user:, entity_name: receiver.first_name.upcase, entity_user: receiver)
      receiver_counterpart = create(:entity, user: receiver, entity_name: user.first_name.upcase, entity_user: user)
      user_card = create(:user_card, :random, user:, card: create(:card, :random, bank: bank))
      receiver_bank_account = create(:user_bank_account, :random, user: receiver, bank: create(:bank, :random))

      card_transaction = create(
        :card_transaction,
        user:,
        context: user.main_context,
        user_card:,
        description: "Receiver manual restructure source",
        date: Time.zone.local(2026, 2, 7, 16, 9, 0),
        month: 3,
        year: 2026,
        price: -12_000
      )
      card_transaction.category_transactions.destroy_all
      card_transaction.category_transactions.create!(category: user.built_in_category("EXCHANGE"))
      entity_transaction = card_transaction.entity_transactions.first
      entity_transaction.update!(entity_id: sender_entity.id, price: -12_000, price_to_be_returned: -12_000, is_payer: true, exchanges_count: 2)
      first_exchange = create(
        :exchange,
        entity_transaction:,
        bound_type: :standalone,
        exchange_type: :monetary,
        number: 1,
        price: -6_000,
        date: Time.zone.local(2026, 3, 2, 10, 25, 0),
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
        date: Time.zone.local(2026, 4, 2, 10, 25, 0),
        month: 4,
        year: 2026
      )

      sender_return = first_exchange.cash_transaction.reload
      receiver_return = create(
        :cash_transaction,
        user: receiver,
        context: receiver.main_context,
        user_bank_account: receiver_bank_account,
        reference_transactable: sender_return,
        description: sender_return.description,
        date: Time.zone.local(2026, 3, 2, 10, 25, 0),
        month: 3,
        year: 2026,
        price: -12_000,
        category_transactions_attributes: [
          { category_id: receiver.built_in_category("BORROW RETURN").id }
        ],
        entity_transactions_attributes: [
          { entity_id: receiver_counterpart.id, is_payer: false, price: 0, price_to_be_returned: 0 }
        ],
        cash_installments_attributes: [
          { number: 1, date: Time.zone.local(2026, 3, 2, 10, 25, 0), month: 3, year: 2026, price: -6_000, paid: false },
          { number: 2, date: Time.zone.local(2026, 4, 2, 10, 25, 0), month: 4, year: 2026, price: -6_000, paid: false }
        ]
      )
      receiver_return.cash_installments.destroy_all
      receiver_return.cash_installments.create!(number: 1, date: Time.zone.local(2026, 3, 2, 10, 25, 0), month: 3, year: 2026, price: -6_000, paid: false)
      receiver_return.cash_installments.create!(number: 2, date: Time.zone.local(2026, 4, 2, 10, 25, 0), month: 4, year: 2026, price: -6_000, paid: false)
      receiver_return.update_columns(cash_installments_count: 2, price: -12_000, starting_price: -12_000)

      sign_out user
      sign_in receiver

      expect do
        patch cash_transaction_path(receiver_return), params: {
          cash_transaction: {
            description: receiver_return.description,
            comment: receiver_return.comment,
            price: -12_000,
            date: Time.zone.local(2026, 3, 2, 10, 25, 0),
            month: 3,
            year: 2026,
            user_id: receiver.id,
            user_bank_account_id: receiver_bank_account.id,
            category_transactions_attributes: receiver_return.category_transactions.map { |record| { id: record.id, category_id: record.category_id } },
            entity_transactions_attributes: [
              {
                id: receiver_return.entity_transactions.first.id,
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
                id: receiver_return.cash_installments.find_by!(number: 1).id,
                number: 1,
                date: Time.zone.local(2026, 3, 2, 10, 25, 0),
                month: 3,
                year: 2026,
                price: -6_000,
                paid: false
              },
              {
                id: receiver_return.cash_installments.find_by!(number: 2).id,
                number: 2,
                date: Time.zone.local(2026, 4, 2, 10, 25, 0),
                month: 4,
                year: 2026,
                price: -3_000,
                paid: false
              },
              {
                number: 3,
                date: Time.zone.local(2026, 5, 2, 10, 25, 0),
                month: 5,
                year: 2026,
                price: -3_000,
                paid: false
              }
            ]
          }
        }, headers: turbo_stream_headers
      end.to change(Message.where(body: "notification:update"), :count).by(1)

      message = Message.where(body: "notification:update").order(:id).last
      replay = JSON.parse(message.headers).fetch("replay")

      expect(response).to have_http_status(:ok)
      expect(message.user).to eq(receiver)
      expect(message.reference_transactable).to eq(sender_return)
      expect(message.conversation.users).to match_array([ receiver, user ])
      expect(replay).to include(
        "id" => sender_return.id,
        "type" => "CashTransaction",
        "category_ids" => [ user.built_in_category("EXCHANGE RETURN").id ]
      )
      expect(replay.fetch("cash_installments_attributes")).to contain_exactly(
        a_hash_including("number" => 1, "price" => sender_return.price.negative? ? -6_000 : 6_000),
        a_hash_including("number" => 2, "price" => sender_return.price.negative? ? -3_000 : 3_000),
        a_hash_including("number" => 3, "price" => sender_return.price.negative? ? -3_000 : 3_000)
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
      expect(response.body).to include(I18n.t("actions.confirm_historical_change"))
      expect(locked_transaction.reload).to be_present
    end

    it "allows confirmed destruction when a transaction has paid history" do
      locked_transaction = create_cash_transaction_with_paid_history(description: "Confirmed destroy cash")

      expect do
        delete cash_transaction_path(locked_transaction, historical_correction_confirmation: true), headers: turbo_stream_headers
      end.to change(CashTransaction, :count).by(-1)

      expect(response).to have_http_status(:ok)
    end

    it "returns unprocessable_entity when destroying a borrow return linked to a shared-return parent" do
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
        description: "Locked linked sender return",
        price: -1000,
        date: Date.new(2026, 3, 10),
        month: 3,
        year: 2026,
        category_transactions_attributes: [ { category_id: sender.built_in_category("EXCHANGE RETURN").id } ],
        entity_transactions_attributes: [ { entity_id: sender.entities.that_are_users.find_by!(entity_user: receiver).id, is_payer: false, price: 0,
                                            price_to_be_returned: 0 } ],
        cash_installments_attributes: [ { number: 1, date: Date.new(2026, 3, 10), month: 3, year: 2026, price: -1000, paid: false } ]
      )

      linked_borrow_return = create(
        :cash_transaction,
        user: receiver,
        context: receiver.main_context,
        user_bank_account: receiver_bank_account,
        reference_transactable: sender_return,
        description: "Locked linked borrow return",
        price: -1000,
        date: Date.new(2026, 3, 10),
        month: 3,
        year: 2026,
        category_transactions_attributes: [ { category_id: receiver.built_in_category("BORROW RETURN").id } ],
        entity_transactions_attributes: [ { entity_id: receiver_counterpart.id, is_payer: false, price: 0, price_to_be_returned: 0 } ],
        cash_installments_attributes: [ { number: 1, date: Date.new(2026, 3, 10), month: 3, year: 2026, price: -1000, paid: false } ]
      )

      sign_out user
      sign_in receiver

      expect do
        delete cash_transaction_path(linked_borrow_return), headers: turbo_stream_headers
      end.not_to change(CashTransaction, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include(I18n.t("notification.not_destroyed", model: CashTransaction.model_name.human))
      expect(linked_borrow_return.reload).to be_present
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

    it "renders row actions in the menu while keeping description links pointed at edit" do
      transaction = create(
        :cash_transaction,
        user:,
        context: user.main_context,
        user_bank_account:,
        description: "Analysable cash row",
        date: Time.zone.today,
        month: Time.zone.today.month,
        year: Time.zone.today.year,
        cash_installments: [
          build(:cash_installment, number: 1, date: Time.zone.today, month: Time.zone.today.month, year: Time.zone.today.year, paid: false)
        ]
      )
      installment = transaction.cash_installments.first

      get month_year_cash_transactions_path, params: {
        month_year: Time.zone.today.strftime("%Y%m"),
        cash_transaction: { user_bank_account_id: user_bank_account.id }
      }

      expect(response).to have_http_status(:success)
      expect(response.body).to include(cash_transaction_path(transaction))
      expect(response.body).to include(edit_cash_transaction_path(transaction))
      expect(response.body).to include(I18n.t("actions.analyse"))
      expect(response.body).to include(duplicate_cash_transaction_path(transaction))
      expect(response.body).to include("delete_cash_transaction_#{transaction.id}")
      expect(response.body).to include("linkWithConfirmDialog_cash_transaction_menu_destroy_#{transaction.id}")
      expect(response.body).not_to include("data-turbo-confirm")

      document = Nokogiri::HTML.fragment(response.body)
      description_link = document.at_css("#edit_cash_transaction_#{transaction.id}")
      description_column = description_link.parent
      action_button = document.at_css("#cash_installment_actions_#{installment.id}")
      pay_action = document.at_css("button[data-modal-toggle='cashInstallmentModal_#{installment.id}']")

      expect(description_link["href"]).to eq(edit_cash_transaction_path(transaction))
      expect(description_column["class"]).to include("col-span-4")
      expect(description_column.text).not_to include(I18n.t("actions.analyse"))
      expect(action_button).to be_present
      expect(pay_action.text).to include(CashInstallment.human_attribute_name(:pay))
    end

    it "does not render row-menu destroy for investment-derived cash rows" do
      transaction = create(
        :cash_transaction,
        user:,
        context: user.main_context,
        user_bank_account:,
        cash_transaction_type: "Investment",
        description: "Investment cash row",
        date: Time.zone.today,
        month: Time.zone.today.month,
        year: Time.zone.today.year,
        cash_installments: [
          build(:cash_installment, number: 1, date: Time.zone.today, month: Time.zone.today.month, year: Time.zone.today.year, paid: true)
        ]
      )

      get month_year_cash_transactions_path, params: {
        month_year: Time.zone.today.strftime("%Y%m"),
        cash_transaction: { user_bank_account_id: user_bank_account.id }
      }

      expect(response).to have_http_status(:success)
      expect(response.body).to include(cash_transaction_path(transaction))
      expect(response.body).not_to include("delete_cash_transaction_#{transaction.id}")
    end

    it "renders the pay modal with autofocus on the payment date input" do
      transaction = create(
        :cash_transaction,
        user:,
        context: user.main_context,
        user_bank_account:,
        date: Time.zone.now,
        month: Time.zone.now.month,
        year: Time.zone.now.year,
        cash_installments: [ build(:cash_installment, number: 1, date: Time.zone.now, month: Time.zone.now.month, year: Time.zone.now.year, paid: false) ]
      )
      cash_installment = transaction.cash_installments.first

      get month_year_cash_transactions_path, params: {
        month_year: Time.zone.today.strftime("%Y%m"),
        cash_transaction: { user_bank_account_id: user_bank_account.id }
      }

      expect(response).to have_http_status(:success)

      document = Nokogiri::HTML.fragment(response.body)
      pay_modal_price = document.at_css("#cashInstallmentModal_#{cash_installment.id} #transaction_price")
      pay_modal_date = document.at_css("#cashInstallmentModal_#{cash_installment.id} #cash_installment_#{cash_installment.id}_payment_date_date_input")

      expect(pay_modal_price["data-controller"]).not_to include("autofocus")
      expect(pay_modal_date["data-controller"]).to include("autofocus")
    end

    it "sorts cash rows by description while keeping budgets visible after them" do
      first_transaction = create(
        :cash_transaction,
        user:,
        context: user.main_context,
        user_bank_account: user_bank_account,
        description: "Zulu rent",
        price: 4_500,
        date: Date.new(2026, 3, 10),
        month: 3,
        year: 2026
      )
      second_transaction = create(
        :cash_transaction,
        user:,
        context: user.main_context,
        user_bank_account: user_bank_account,
        description: "Alpha salary",
        price: 9_500,
        date: Date.new(2026, 3, 11),
        month: 3,
        year: 2026
      )
      budget = create(
        :budget,
        user:,
        context: user.main_context,
        description: "March household budget",
        month: 3,
        year: 2026,
        value: -3_000,
        remaining_value: -3_000
      )

      get month_year_cash_transactions_path, params: {
        month_year: "202603",
        sort: "description",
        direction: "asc",
        cash_transaction: { user_bank_account_id: user_bank_account.id }
      }

      expect(response).to have_http_status(:success)
      expect(response.body.index("edit_cash_transaction_#{first_transaction.id}")).to be > response.body.index("edit_cash_transaction_#{second_transaction.id}")
      expect(response.body).not_to include('data-sort-field="default"')
      expect(response.body).not_to include('data-sort-field="installment_date"')
      expect(response.body).not_to include('data-sort-field="transaction_date"')
      expect(response.body).not_to include('data-sort-field="description"')
      expect(response.body).not_to include('data-sort-field="price"')
      expect(response.body).to include("edit_budget_#{budget.id}")
      expect(response.body.index("edit_budget_#{budget.id}")).to be > response.body.index("edit_cash_transaction_#{second_transaction.id}")
    end

    it "sorts cash rows by transaction date ascending" do
      later_transaction = create(
        :cash_transaction,
        user:,
        context: user.main_context,
        user_bank_account: user_bank_account,
        description: "Later booking",
        price: 4_000,
        date: Date.new(2026, 3, 22),
        month: 3,
        year: 2026
      )
      earlier_transaction = create(
        :cash_transaction,
        user:,
        context: user.main_context,
        user_bank_account: user_bank_account,
        description: "Earlier booking",
        price: 4_000,
        date: Date.new(2026, 3, 3),
        month: 3,
        year: 2026
      )

      get month_year_cash_transactions_path, params: {
        month_year: "202603",
        sort: "transaction_date",
        direction: "asc",
        cash_transaction: { user_bank_account_id: user_bank_account.id }
      }

      expect(response).to have_http_status(:success)
      expect(response.body.index("edit_cash_transaction_#{earlier_transaction.id}")).to be <
                                                                                        response.body.index("edit_cash_transaction_#{later_transaction.id}")
    end

    it "filters cash rows by the explicit paid state" do
      paid_transaction = create(
        :cash_transaction,
        user:,
        context: user.main_context,
        user_bank_account: user_bank_account,
        description: "Already paid rent",
        price: 4_000,
        date: Date.new(2026, 3, 8),
        month: 3,
        year: 2026
      )
      pending_transaction = create(
        :cash_transaction,
        user:,
        context: user.main_context,
        user_bank_account: user_bank_account,
        description: "Pending rent",
        price: 4_000,
        date: Date.new(2026, 3, 9),
        month: 3,
        year: 2026
      )
      paid_transaction.cash_installments.first.update!(paid: true)
      pending_transaction.cash_installments.first.update!(paid: false)

      get month_year_cash_transactions_path, params: {
        month_year: "202603",
        paid_state: "pending",
        cash_transaction: { user_bank_account_id: user_bank_account.id }
      }

      expect(response).to have_http_status(:success)
      expect(response.body).to include("edit_cash_transaction_#{pending_transaction.id}")
      expect(response.body).not_to include("edit_cash_transaction_#{paid_transaction.id}")
    end

    it "filters exchange return cash rows by exchange bound type" do
      card_bound_source = create(
        :card_transaction,
        user:,
        context: user.main_context,
        user_card: create(:user_card, :random, user:, card: create(:card, :random, bank: bank)),
        description: "Card-bound mirrored return source",
        date: Date.new(2026, 3, 20),
        month: 4,
        year: 2026,
        price: -2_000
      )
      card_bound_source.category_transactions.destroy_all
      card_bound_source.category_transactions.create!(category: user.built_in_category("EXCHANGE"))
      payer_card_bound = card_bound_source.entity_transactions.first
      payer_card_bound.update!(price: -2_000, price_to_be_returned: -2_000, is_payer: true, exchanges_count: 1)
      card_bound_exchange = create(
        :exchange,
        entity_transaction: payer_card_bound,
        bound_type: :card_bound,
        exchange_type: :monetary,
        number: 1,
        price: -2_000,
        date: Date.new(2026, 4, 20),
        month: 4,
        year: 2026
      )
      card_bound_return = card_bound_exchange.cash_transaction.reload

      standalone_source = create(
        :cash_transaction,
        user:,
        context: user.main_context,
        user_bank_account: user_bank_account,
        description: "Standalone mirrored return source",
        date: Date.new(2026, 4, 21),
        month: 4,
        year: 2026,
        price: -2_500
      )
      standalone_source.category_transactions.destroy_all
      standalone_source.category_transactions.create!(category: user.built_in_category("EXCHANGE"))
      standalone_entity = standalone_source.entity_transactions.first&.entity || create(:entity, :random, user:)
      payer_standalone = standalone_source.entity_transactions.first || create(
        :entity_transaction,
        transactable: standalone_source,
        entity: standalone_entity,
        is_payer: true,
        price: -2_500,
        price_to_be_returned: -2_500
      )
      payer_standalone.update!(entity: standalone_entity, is_payer: true, price: -2_500, price_to_be_returned: -2_500)
      standalone_exchange = create(
        :exchange,
        entity_transaction: payer_standalone,
        bound_type: :standalone,
        exchange_type: :monetary,
        number: 1,
        price: -2_500,
        date: Date.new(2026, 4, 21),
        month: 4,
        year: 2026
      )
      standalone_return = standalone_exchange.cash_transaction.reload

      get month_year_cash_transactions_path, params: {
        month_year: "202604",
        exchange_bound_type: "card_bound",
        cash_transaction: {
          category_id: [ user.built_in_category("EXCHANGE RETURN").id ]
        }
      }

      expect(response).to have_http_status(:success)
      expect(response.body).to include(card_bound_return.description)
      expect(response.body).not_to include(standalone_return.description)
    end

    it "does not duplicate a cash row when categories and entities create join fanout" do
      transaction = create(
        :cash_transaction,
        user:,
        context: user.main_context,
        user_bank_account: user_bank_account,
        description: "Fanout cash row",
        date: Date.new(2026, 4, 18),
        month: 4,
        year: 2026,
        price: 1_719
      )

      extra_category = create(:category, :random, user:)
      extra_entity = create(:entity, :random, user:)

      transaction.category_transactions.create!(category: extra_category)
      transaction.entity_transactions.create!(entity: extra_entity, price: 0, price_to_be_returned: 0)

      get month_year_cash_transactions_path, params: {
        month_year: "202604",
        cash_transaction: { user_bank_account_id: user_bank_account.id }
      }

      expect(response).to have_http_status(:success)
      expect(response.body.scan("edit_cash_transaction_#{transaction.id}").size).to eq(1)
    end

    it "sorts cash rows by price descending" do
      smaller_transaction = create(
        :cash_transaction,
        user:,
        context: user.main_context,
        user_bank_account: user_bank_account,
        description: "Smaller payment",
        price: 2_000,
        date: Date.new(2026, 3, 10),
        month: 3,
        year: 2026
      )
      bigger_transaction = create(
        :cash_transaction,
        user:,
        context: user.main_context,
        user_bank_account: user_bank_account,
        description: "Bigger payment",
        price: 8_000,
        date: Date.new(2026, 3, 11),
        month: 3,
        year: 2026
      )

      get month_year_cash_transactions_path, params: {
        month_year: "202603",
        sort: "price",
        direction: "desc",
        cash_transaction: { user_bank_account_id: user_bank_account.id }
      }

      expect(response).to have_http_status(:success)
      expect(response.body.index("edit_cash_transaction_#{bigger_transaction.id}")).to be <
                                                                                       response.body.index("edit_cash_transaction_#{smaller_transaction.id}")
    end
  end
end
