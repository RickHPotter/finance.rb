# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Entity ledger presentation", type: :request do
  let(:owner) { create(:user, :random, first_name: "LEDGER OWNER") }
  let(:entity) { create(:entity, user: owner, entity_name: "SHARED ENTITY") }
  let(:context) { owner.main_context }
  let(:share) { Ledgers::Shares::Create.call(entity:, context:) }

  describe "external presentation" do
    it "renders identity and only the allowlisted cash projection without private application chrome" do
      installment = create_cash_installment

      get external_cash_transactions_path(share_token: share.token), params: {
        active_month_years: [ 202_609 ].to_json,
        default_year: 2026,
        search_term: "ALLOWLISTED",
        paid: true,
        pending: false,
        sort: "price",
        direction: "desc"
      }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("LEDGER OWNER", "SHARED ENTITY", context.name, "people/0")
      expect(response.body).to include('name="referrer" content="no-referrer"')
      expect(response.body).not_to include("current-user-id", "notification", "theme_toggle")
      document = response.parsed_body
      expect(document.at_css("[data-ledger-aggregate-total]")["data-price"]).to eq("-12345")
      card_link = document.css("nav[aria-label='Ledger type'] a").find { |link| link.text.squish == "Card" }
      expect(card_link["href"]).to eq(external_card_transactions_path(share_token: share.token))

      get month_year_external_cash_transactions_path(share_token: share.token), params: { month_year: 202_609 }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("ALLOWLISTED DESCRIPTION", "1/1", "Paid", "1 matching entry", "1 entry in this result")
      expect(response.body).not_to include(
        "PRIVATE COMMENT",
        "PRIVATE ACCOUNT",
        "PRIVATE CATEGORY",
        "PRIVATE OTHER ENTITY",
        "cash_installment_#{installment.id}",
        "cash_transactions/#{installment.cash_transaction_id}"
      )
      expect(response.body).not_to match(/data-turbo-method|method="(?:post|patch|delete)"/)

      document = response.parsed_body
      exchange_return = installment.cash_transaction.categories.find_by!(category_name: "EXCHANGE RETURN")
      expect(document.at_css("article")["style"]).to include(CategoryColours::Presentation.for(exchange_return).inline_style)
      desktop_row = document.at_css("article").text.squish
      get month_year_external_cash_transactions_path(share_token: share.token), params: { month_year: 202_609, force_mobile: true }
      mobile_row = Nokogiri::HTML(response.body).at_css("article").text.squish
      expect(mobile_row).to eq(desktop_row)
    end

    it "ignores private account filters instead of reflecting or applying them" do
      installment = create_cash_installment
      foreign_account = create(:user_bank_account, :random, user: create(:user, :random), bank: create(:bank, :random))

      get external_cash_transactions_path(share_token: share.token), params: {
        cash_transaction: { user_bank_account_id: foreign_account.id },
        active_month_years: [ 202_609 ].to_json
      }

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("user_bank_account_id")

      get month_year_external_cash_transactions_path(share_token: share.token), params: {
        month_year: 202_609,
        cash_transaction: { user_bank_account_id: foreign_account.id }
      }

      expect(response.body).to include("ALLOWLISTED DESCRIPTION")
      expect(response.body).not_to include("cash_installment_#{installment.id}")
    end

    it "renders a clear responsive empty state in both colour modes" do
      get month_year_external_cash_transactions_path(share_token: share.token), params: { month_year: 202_609 }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("No ledger entries found", "Try another month or adjust the filters.")
      expect(response.body).to include("dark:")
    end

    it "uses the same allowlisted projection for card billing periods" do
      installment = create_card_installment

      get month_year_external_card_transactions_path(share_token: share.token), params: { month_year: 202_609 }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("ALLOWLISTED CARD", "September 2026", "1/1", "Pending")
      expect(response.body).not_to include(
        "PRIVATE CARD COMMENT",
        "PRIVATE USER CARD",
        "PRIVATE CARD CATEGORY",
        "PRIVATE CARD ENTITY",
        "card_installment_#{installment.id}",
        "card_transactions/#{installment.card_transaction_id}"
      )
    end

    it "keeps the public ledger semantic, keyboard-addressable, and free of mutation forms" do
      create_cash_installment

      get external_cash_transactions_path(share_token: share.token), params: {
        active_month_years: [ 202_609 ].to_json,
        default_year: 2026
      }

      document = response.parsed_body
      expect(document.at_css("html")["lang"]).to eq("en")
      expect(document.css("h1").map(&:text).map(&:squish)).to eq([ "SHARED ENTITY" ])
      expect(document.at_css("nav[aria-label='Ledger type'] a[aria-current='page']").text.squish).to eq("Cash")
      expect(document.at_css("select#ledger_sort[aria-label='Sort ledger']")).to be_present
      expect(document.at_css("select#ledger_direction[aria-label='Sort direction']")).to be_present
      expect(document.at_css("main")["class"]).to include("max-w-355")
      expect(document.css("form")).to all(satisfy { |form| form["method"] == "get" })
      expect(document.css("form input[name='authenticity_token']")).to be_empty
      expect(duplicate_ids(document)).to be_empty
    end
  end

  describe "internal presentation" do
    it "keeps owner-only Category and Entity allocation details" do
      create_cash_installment
      sign_in owner

      get month_year_internal_cash_transactions_path(entity_public_id: entity.public_id), params: { month_year: 202_609 }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("PRIVATE CATEGORY", "PRIVATE OTHER ENTITY")
    end
  end

  private

  def duplicate_ids(document)
    document.css("[id]").map { |node| node["id"] }.tally.select { |_id, count| count > 1 }.keys
  end

  def create_cash_installment
    account = create(:user_bank_account, :random, user: owner, bank: create(:bank, :random), user_bank_account_name: "PRIVATE ACCOUNT")
    exchange_return = owner.categories.find_by(category_name: "EXCHANGE RETURN") || create(:category, :random, user: owner, category_name: "EXCHANGE RETURN")
    private_category = create(:category, :random, user: owner, category_name: "PRIVATE CATEGORY")
    private_entity = create(:entity, user: owner, entity_name: "PRIVATE OTHER ENTITY")
    transaction = create(
      :cash_transaction,
      user: owner,
      context:,
      user_bank_account: account,
      description: "ALLOWLISTED DESCRIPTION",
      comment: "PRIVATE COMMENT",
      date: Time.zone.local(2026, 9, 10, 12),
      month: 9,
      year: 2026,
      price: -12_345,
      cash_installments: [],
      category_transactions_attributes: [ { category_id: exchange_return.id }, { category_id: private_category.id } ],
      entity_transactions_attributes: [
        { entity_id: entity.id, is_payer: false, price: 0, price_to_be_returned: 0 },
        { entity_id: private_entity.id, is_payer: false, price: 0, price_to_be_returned: 0 }
      ],
      cash_installments_attributes: [
        { number: 1, date: Time.zone.local(2026, 9, 10, 12), month: 9, year: 2026, price: -12_345, paid: true }
      ]
    )
    transaction.cash_installments.first
  end

  def create_card_installment
    user_card = create(
      :user_card,
      :random,
      user: owner,
      card: create(:card, :random, bank: create(:bank, :random)),
      user_card_name: "PRIVATE USER CARD"
    )
    private_category = create(:category, :random, user: owner, category_name: "PRIVATE CARD CATEGORY")
    private_entity = create(:entity, user: owner, entity_name: "PRIVATE CARD ENTITY")
    transaction = create(
      :card_transaction,
      user: owner,
      context:,
      user_card:,
      description: "ALLOWLISTED CARD",
      comment: "PRIVATE CARD COMMENT",
      date: Time.zone.local(2026, 8, 10, 12),
      month: 9,
      year: 2026,
      price: -5000,
      card_installments: [
        build(:card_installment, number: 1, date: Time.zone.local(2026, 8, 10, 12), month: 9, year: 2026, price: -5000)
      ]
    )
    replace_card_allocations(transaction, private_category:, private_entity:)
    transaction.card_installments.first
  end

  def replace_card_allocations(transaction, private_category:, private_entity:)
    transaction.category_transactions.destroy_all
    transaction.entity_transactions.destroy_all
    transaction.category_transactions.create!(category: owner.built_in_category("EXCHANGE"))
    transaction.category_transactions.create!(category: private_category)
    transaction.entity_transactions.create!(entity:, is_payer: false, price: 0, price_to_be_returned: 0)
    transaction.entity_transactions.create!(entity: private_entity, is_payer: false, price: 0, price_to_be_returned: 0)
  end
end
