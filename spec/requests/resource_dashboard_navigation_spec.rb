# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Resource dashboard navigation", type: :request do
  let(:user) { create(:user, :random) }
  let(:context) { user.main_context }
  let(:account) { create(:user_bank_account, :random, user:) }
  let(:user_card) { create(:user_card, :random, user:) }
  let(:category) { create(:category, :random, user:) }
  let(:entity) { create(:entity, :random, user:) }
  let(:cash_transaction) do
    create(:cash_transaction, :random, user:, context:, user_bank_account: account, categories: [ category ], entities: [ entity ])
  end
  let(:card_transaction) do
    create(:card_transaction, :random, user:, context:, user_card:, categories: [ category ], entities: [ entity ])
  end
  let(:budget) do
    create(
      :budget,
      user:,
      context:,
      year: cash_transaction.year,
      month: cash_transaction.month,
      budget_categories: [ build(:budget_category, category:) ],
      budget_entities: [ build(:budget_entity, entity:) ]
    )
  end

  before do
    sign_in user
    cash_transaction
    card_transaction
  end

  it "renders exact list actions on every existing financial dashboard" do
    expected_links = {
      cash_transaction_path(cash_transaction) => cash_transactions_path(
        all_month_years: true,
        cash_transaction: { id: [ cash_transaction.id ] },
        return_to: cash_transaction_path(cash_transaction)
      ),
      card_transaction_path(card_transaction) => card_transactions_path(
        all_month_years: true,
        card_transaction: { id: [ card_transaction.id ] },
        return_to: card_transaction_path(card_transaction)
      ),
      budget_path(budget) => budgets_path(
        default_year: budget.year,
        active_month_years: [ Date.new(budget.year, budget.month, 1).strftime("%Y%m").to_i ].to_json,
        budget: { id: [ budget.id ] },
        return_to: budget_path(budget)
      ),
      user_bank_account_path(account) => cash_transactions_path(
        all_month_years: true,
        cash_transaction: { user_bank_account_id: [ account.id ] },
        return_to: user_bank_account_path(account)
      ),
      user_card_path(user_card) => card_transactions_path(
        all_month_years: true,
        user_card_id: user_card.id,
        return_to: user_card_path(user_card)
      )
    }

    expected_links.each do |show_path, expected_href|
      get show_path

      expect(response).to have_http_status(:success)
      expect(parsed_document.css("a").map { |link| link["href"] }).to include(expected_href)
    end
  end

  it "renders exact typed collection and merge actions on category and entity dashboards" do
    expectations = {
      category_path(category) => [
        cash_transactions_path(all_month_years: true, cash_transaction: { category_id: [ category.id ] }, return_to: category_path(category)),
        card_transactions_path(all_month_years: true, card_transaction: { category_id: [ category.id ] }, return_to: category_path(category)),
        merge_preview_category_path(category, category_merge: { return_to: category_path(category) })
      ],
      entity_path(entity) => [
        cash_transactions_path(all_month_years: true, cash_transaction: { entity_id: [ entity.id ] }, return_to: entity_path(entity)),
        card_transactions_path(all_month_years: true, card_transaction: { entity_id: [ entity.id ] }, return_to: entity_path(entity)),
        merge_preview_entity_path(entity, entity_merge: { return_to: entity_path(entity) })
      ]
    }

    expectations.each do |show_path, expected_hrefs|
      get show_path
      links = parsed_document.css("a")

      expect(links.map { |link| link["href"] }).to include(*expected_hrefs)
      expected_hrefs.last.then do |merge_href|
        expect(links.find { |link| link["href"] == merge_href }&.[]("data-turbo-method")).to eq("post")
      end
    end
  end

  it "preserves an owned source dashboard through filtered indexes and typed show links" do
    get cash_transactions_path(
      all_month_years: true,
      cash_transaction: { user_bank_account_id: [ account.id ] },
      return_to: user_bank_account_path(account)
    )

    expect(parsed_document.at_css(%(input[name="return_to"][value="#{user_bank_account_path(account)}"]))).to be_present

    get card_transaction_path(card_transaction, return_to: cash_transaction_path(cash_transaction))

    edit_href = edit_card_transaction_path(card_transaction, return_to: cash_transaction_path(cash_transaction))
    expect(parsed_document.css("a").map { |link| link["href"] }).to include(edit_href)
  end

  it "turns reference descendant counts into exact typed links with a dashboard return" do
    cash_child = create(
      :cash_transaction,
      :random,
      user:,
      context:,
      user_bank_account: account,
      reference_transactable: cash_transaction
    )
    card_child = create(
      :card_transaction,
      :random,
      user:,
      context:,
      user_card:,
      reference_transactable: card_transaction
    )

    get cash_transaction_path(cash_transaction)
    expect(parsed_document.css("a").map { |link| link["href"] }).to include(
      cash_transaction_path(cash_child, return_to: cash_transaction_path(cash_transaction))
    )

    get card_transaction_path(card_transaction)
    expect(parsed_document.css("a").map { |link| link["href"] }).to include(
      card_transaction_path(card_child, return_to: card_transaction_path(card_transaction))
    )
  end

  it "rejects a foreign source dashboard and falls back to the resource index" do
    foreign_user = create(:user, :random)
    foreign_account = create(:user_bank_account, :random, user: foreign_user)

    get cash_transaction_path(cash_transaction, return_to: user_bank_account_path(foreign_account))

    expect(parsed_document.css("a").map { |link| link["href"] }).to include(
      edit_cash_transaction_path(cash_transaction, return_to: cash_transactions_path)
    )
  end

  private

  def parsed_document
    Nokogiri::HTML.parse(response.body)
  end
end
