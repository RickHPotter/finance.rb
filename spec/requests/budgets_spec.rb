# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Budgets", type: :request do
  let(:user) { create(:user, :random) }
  let(:category) { create(:category, :random, user:) }
  let(:entity) { create(:entity, :random, user:) }
  let(:bank) { create(:bank, :random) }
  let(:user_bank_account) { create(:user_bank_account, :random, user:, bank:) }

  before { sign_in user }

  def switch_to_context!(context)
    patch switch_context_path(context)
    expect(response).to redirect_to(root_path)
  end

  describe "[ #index ]" do
    it "renders successfully" do
      get budgets_path

      expect(response).to have_http_status(:success)
    end

    it "keeps budget filters compact without summary chips or sorting controls" do
      get budgets_path, params: {
        search_term: "food",
        budget: { category_id: [ category.id ] }
      }

      expect(response).to have_http_status(:success)
      expect(response.body).not_to include('data-sort-field="description"')
      expect(response.body).not_to include(I18n.t("filters.summary.active"))

      document = Nokogiri::HTML.fragment(response.body)
      chips = document.css("a[aria-label^=\"#{I18n.t('filters.summary.clear')}\"]")

      expect(chips).to be_empty
    end
  end

  describe "[ #create ]" do
    it "creates a budget" do
      expect do
        post budgets_path, params: {
          budget: {
            description: "Food Budget",
            value: -10_000,
            inclusive: false,
            first_installment_only: false,
            month_year: "2026-03",
            active: true,
            user_id: user.id,
            budget_categories_attributes: [ { category_id: category.id } ],
            budget_entities_attributes: []
          }
        }, headers: turbo_stream_headers
      end.to change(Budget, :count).by(1)
    end
  end

  describe "[ #new ]" do
    it "renders RubyUI comboboxes for category and entity selection" do
      create(:entity, :random, user:)

      get new_budget_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include("New")
      expect(response.body).to include('data-controller="form-loading"')
      expect(response.body).to include('id="budget_form_submission_skeleton"')
      expect(response.body).to include('data-controller="ruby-ui--combobox"')
      expect(response.body).to include('data-controller="reactive-form price-mask dynamic-description"')
      expect(response.body).to include('data-reactive-form-quick-jump-value="true"')
      expect(response.body).to include('data-reactive-form-target="monthYearCombobox"')
      expect(response.body).to include('data-reactive-form-target="priceInput"')
      expect(response.body).not_to include("hw-combobox")
    end

    it "renders the edit month field as a quick jump target" do
      budget = create(:budget, user:, budget_categories: [ build(:budget_category, category:) ])

      get edit_budget_path(budget)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Editing")
      expect(response.body).to include('data-reactive-form-quick-jump-value="true"')
      expect(response.body).to include('data-reactive-form-target="monthYearInput"')
    end

    it "renders a duplicated budget form without creating a new record" do
      budget = create(
        :budget,
        user:,
        description: "Duplicated budget",
        month: 3,
        year: 2026,
        value: -10_000,
        budget_categories: [ build(:budget_category, category:) ]
      )

      expect { get duplicate_budget_path(budget) }.not_to change(Budget, :count)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Duplicating")
      expect(response.body).to include('id="budget_form_submission_skeleton"')
    end
  end

  describe "[ #show ]" do
    it "renders a context-scoped dashboard with summary, definition, consumption, and actions" do
      cash_transaction = create(
        :cash_transaction,
        user:,
        context: user.main_context,
        user_bank_account:,
        description: "Groceries for budget",
        date: Date.new(2026, 3, 10),
        month: 3,
        year: 2026,
        price: -2_500,
        cash_installments: [
          build(:cash_installment, number: 1, date: Date.new(2026, 3, 10), month: 3, year: 2026, price: -2_500, paid: true)
        ],
        category_transactions: [ build(:category_transaction, category:) ]
      )
      budget = create(
        :budget,
        user:,
        context: user.main_context,
        description: "Budget dashboard details",
        month: 3,
        year: 2026,
        value: -10_000,
        budget_categories: [ build(:budget_category, category:) ]
      )

      get budget_path(budget)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Budget dashboard details")
      expect(response.body).to include("Groceries for budget")
      expect(response.body).to include(I18n.t("dashboards.budgets.consumption"))
      expect(response.body).to include(I18n.t("dashboards.budgets.definition"))
      expect(response.body).to include(I18n.t("dashboards.sections.summary"))
      expect(response.body).to include(edit_budget_path(budget))
      expect(response.body).to include(duplicate_budget_path(budget))
      expect(response.body).to include(cash_transaction_path(cash_transaction))
      expect(response.body).to include("delete_budget_#{budget.id}")
      expect(response.body).to include(category.name)
    end

    it "shows Available for expense budgets that still have room remaining" do
      create(
        :cash_transaction,
        user:,
        context: user.main_context,
        user_bank_account:,
        description: "Partially consumed budget",
        date: Date.new(2026, 3, 10),
        month: 3,
        year: 2026,
        price: -25_787,
        cash_installments: [
          build(:cash_installment, number: 1, date: Date.new(2026, 3, 10), month: 3, year: 2026, price: -25_787, paid: true)
        ],
        category_transactions: [ build(:category_transaction, category:) ]
      )
      budget = create(
        :budget,
        user:,
        context: user.main_context,
        description: "Expense budget status",
        month: 3,
        year: 2026,
        value: -60_000,
        budget_categories: [ build(:budget_category, category:) ]
      )

      get budget_path(budget)

      expect(response).to have_http_status(:success)
      expect(response.body).to include(I18n.t("dashboards.budgets.status.available"))
      expect(response.body).not_to include(I18n.t("dashboards.budgets.status.exceeded"))
    end
  end

  describe "[ #update ]" do
    it "updates the record" do
      budget = create(:budget, user:, budget_categories: [ build(:budget_category, category:) ])

      patch budget_path(budget), params: {
        budget: {
          description: "Updated Budget",
          value: budget.value,
          inclusive: budget.inclusive,
          first_installment_only: budget.first_installment_only,
          month: budget.month,
          year: budget.year,
          active: budget.active,
          user_id: user.id,
          budget_categories_attributes: budget.budget_categories.map { |bc| { id: bc.id, category_id: bc.category_id } },
          budget_entities_attributes: []
        }
      }, headers: turbo_stream_headers

      expect(budget.reload.description).to eq("Updated Budget")
    end

    it "keeps an existing single category while adding a new entity" do
      budget = create(:budget, user:, budget_categories: [ build(:budget_category, category:) ])

      expect do
        patch budget_path(budget), params: {
          budget: {
            description: budget.description,
            value: budget.value,
            inclusive: budget.inclusive,
            first_installment_only: budget.first_installment_only,
            month: budget.month,
            year: budget.year,
            active: budget.active,
            user_id: user.id,
            budget_categories_attributes: budget.budget_categories.map { |bc| { id: bc.id, category_id: bc.category_id } },
            budget_entities_attributes: [ { entity_id: entity.id } ]
          }
        }, headers: turbo_stream_headers
      end.not_to raise_error

      budget.reload
      expect(budget.budget_categories.count).to eq(1)
      expect(budget.budget_categories.first.category_id).to eq(category.id)
      expect(budget.budget_entities.count).to eq(1)
      expect(budget.budget_entities.first.entity_id).to eq(entity.id)
    end
  end

  describe "[ #destroy ]" do
    it "destroys the record" do
      budget = create(:budget, user:, budget_categories: [ build(:budget_category, category:) ])

      expect do
        delete budget_path(budget), headers: turbo_stream_headers
      end.to change(Budget, :count).by(-1)
    end
  end

  describe "[ #month_year ]" do
    it "renders Analyse links while keeping description links pointed at edit" do
      budget = create(:budget, user:, month: 3, year: 2026, budget_categories: [ build(:budget_category, category:) ])

      get month_year_budgets_path, params: { month_year: "202603" }

      expect(response).to have_http_status(:success)
      expect(response.body).to include(budget_path(budget))
      expect(response.body).to include(edit_budget_path(budget))
      expect(response.body).to include(I18n.t("actions.analyse"))
      expect(response.body).to include(I18n.t("actions.duplicate"))
      expect(response.body).to include(I18n.t("actions.destroy"))
      expect(response.body).to include("delete_budget_#{budget.id}")
      expect(response.body).to include("linkWithConfirmDialog_budget_menu_destroy_#{budget.id}")
      expect(response.body).to include(duplicate_budget_path(budget))

      document = Nokogiri::HTML.fragment(response.body)
      description_link = document.at_css("#edit_budget_#{budget.id}")
      analyse_link = document.at_css("#analyse_budget_#{budget.id}")
      duplicate_link = document.at_css("#duplicate_budget_#{budget.id}")
      action_button = document.at_css("#budget_actions_#{budget.id}")

      expect(description_link["href"]).to eq(edit_budget_path(budget))
      expect(analyse_link["href"]).to eq(budget_path(budget))
      expect(duplicate_link["href"]).to eq(duplicate_budget_path(budget))
      expect(action_button).to be_present
    end
  end

  describe "[ context isolation ]" do
    it "keeps create, update, and destroy changes inside the derived context" do
      main_budget = create(
        :budget,
        user:,
        context: user.main_context,
        description: "Main isolated budget",
        month: 3,
        year: 2026,
        budget_categories: [ build(:budget_category, category:) ]
      )

      derived_context = Logic::ContextCloneService.new(
        source_context: user.main_context,
        name: "Budget Isolation"
      ).call
      derived_budget = derived_context.budgets.find_by!(description: main_budget.description)

      switch_to_context!(derived_context)

      expect do
        post budgets_path, params: {
          budget: {
            description: "Derived only budget",
            value: -20_000,
            inclusive: false,
            first_installment_only: false,
            month_year: "2026-04",
            active: true,
            user_id: user.id,
            budget_categories_attributes: [ { category_id: category.id } ],
            budget_entities_attributes: []
          }
        }, headers: turbo_stream_headers
      end.to change { derived_context.budgets.reload.count }.by(1)
                                                            .and change { user.main_context.budgets.reload.count }.by(0)

      patch budget_path(derived_budget), params: {
        budget: {
          description: "Derived updated budget",
          value: derived_budget.value,
          inclusive: derived_budget.inclusive,
          first_installment_only: derived_budget.first_installment_only,
          month: derived_budget.month,
          year: derived_budget.year,
          active: derived_budget.active,
          user_id: user.id,
          budget_categories_attributes: derived_budget.budget_categories.map { |bc| { id: bc.id, category_id: bc.category_id } },
          budget_entities_attributes: []
        }
      }, headers: turbo_stream_headers

      expect(derived_budget.reload.description).to eq("Derived updated budget")
      expect(main_budget.reload.description).to eq("Main isolated budget")

      expect do
        delete budget_path(derived_budget), headers: turbo_stream_headers
      end.to change { derived_context.budgets.reload.count }.by(-1)
                                                            .and change { user.main_context.budgets.reload.count }.by(0)

      expect(Budget.exists?(main_budget.id)).to be(true)
    end
  end

  describe "[ cross-context access denial ]" do
    it "does not allow editing, updating, or destroying a main-context budget while in a derived context" do
      main_budget = create(
        :budget,
        user:,
        context: user.main_context,
        description: "Main inaccessible budget",
        budget_categories: [ build(:budget_category, category:) ]
      )

      derived_context = Logic::ContextCloneService.new(
        source_context: user.main_context,
        name: "Budget Access Isolation"
      ).call

      switch_to_context!(derived_context)

      get budget_path(main_budget)
      expect(response).to have_http_status(:not_found)

      get edit_budget_path(main_budget)
      expect(response).to have_http_status(:not_found)

      patch budget_path(main_budget), params: {
        budget: {
          description: "Should not update",
          value: main_budget.value,
          inclusive: main_budget.inclusive,
          first_installment_only: main_budget.first_installment_only,
          month: main_budget.month,
          year: main_budget.year,
          active: main_budget.active,
          user_id: user.id,
          budget_categories_attributes: main_budget.budget_categories.map { |bc| { id: bc.id, category_id: bc.category_id } },
          budget_entities_attributes: []
        }
      }, headers: turbo_stream_headers
      expect(response).to have_http_status(:not_found)

      delete budget_path(main_budget), headers: turbo_stream_headers
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "[ form context isolation ]" do
    it "renders exchange return helpers using only the current context records" do
      user_card = create(:user_card, :random, user:, card: create(:card, :random, bank:))
      budget = create(
        :budget,
        user:,
        context: user.main_context,
        description: "Transport Budget",
        month: 3,
        year: 2026,
        budget_categories: [ build(:budget_category, category:) ]
      )
      exchange_return_category = user.built_in_category("EXCHANGE RETURN")

      main_card_transaction = create(
        :card_transaction,
        user:,
        context: user.main_context,
        user_card:,
        description: "Main budget card",
        date: Date.new(2026, 2, 10),
        month: 3,
        year: 2026,
        price: -1000,
        paid: false
      )
      main_card_transaction.categories = [ category ]
      main_card_transaction.save!

      main_exchange_return = create(
        :cash_transaction,
        user:,
        context: user.main_context,
        user_bank_account:,
        user_card:,
        description: "Main budget exchange return",
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

      derived_context = Logic::ContextCloneService.new(source_context: user.main_context, name: "Budget Form Isolation").call
      derived_budget = derived_context.budgets.find_by!(description: budget.description)
      derived_exchange_return = derived_context.cash_transactions.find_by!(description: "Main budget exchange return")

      switch_to_context!(derived_context)

      get edit_budget_path(derived_budget)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("cash_transaction%5Bcash_installment_ids%5D%5B%5D=#{derived_exchange_return.cash_installments.first.id}")
      expect(response.body).not_to include("cash_transaction%5Bcash_installment_ids%5D%5B%5D=#{main_exchange_return.cash_installments.first.id}")
    end
  end
end
