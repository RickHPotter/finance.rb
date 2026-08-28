# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Investments", type: :request do
  let(:user) { create(:user, :random) }
  let(:bank) { create(:bank, :random) }
  let(:user_bank_account) { create(:user_bank_account, :random, user:, bank:) }
  let(:investment_type) { create(:investment_type, :random) }

  before { sign_in user }

  def create_piggy_bank_return
    source = build(
      :cash_transaction,
      user:,
      context: user.main_context,
      user_bank_account:,
      description: "Emergency reserve",
      price: -5_000,
      cash_installments: [ build(:cash_installment, number: 1, price: -5_000, date: Time.zone.now) ],
      category_transactions: [ CategoryTransaction.new(category: user.built_in_category("PIGGY BANK")) ],
      entity_transactions: [ EntityTransaction.new(entity: create(:entity, :random, user:), price: 0, price_to_be_returned: 0, is_payer: false) ],
      piggy_bank: PiggyBank.new(return_price: 5_000, return_date: 3.months.from_now)
    )
    source.save!
    source.piggy_bank.return_cash_transaction
  end

  def switch_to_context!(context)
    patch switch_context_path(context)
    expect(response).to redirect_to(root_path)
  end

  describe "[ #index ]" do
    it "renders successfully" do
      get investments_path

      expect(response).to have_http_status(:success)
    end

    it "renders a duplicate action that uses the duplicate route" do
      investment = create(
        :investment,
        user:,
        context: user.main_context,
        user_bank_account:,
        investment_type:,
        date: Time.zone.today,
        month: Time.zone.today.month,
        year: Time.zone.today.year
      )

      get month_year_investments_path, params: {
        month_year: Time.zone.today.strftime("%Y%m"),
        investment: { user_bank_account_id: user_bank_account.id }
      }

      expect(response).to have_http_status(:success)

      document = Nokogiri::HTML.fragment(response.body)
      duplicate_link = document.at_css("#duplicate_investment_#{investment.id}")

      expect(duplicate_link).to be_present
      expect(duplicate_link["href"]).to eq(duplicate_investment_path(investment))
      expect(duplicate_link["href"]).not_to include("next_day")
    end

    it "links the investment label to show and keeps a distinct edit action" do
      investment = create(
        :investment,
        user:,
        context: user.main_context,
        user_bank_account:,
        investment_type:,
        date: Time.zone.today,
        month: Time.zone.today.month,
        year: Time.zone.today.year
      )

      get month_year_investments_path, params: { month_year: Time.zone.today.strftime("%Y%m") }

      document = Nokogiri::HTML.fragment(response.body)

      expect(document.at_css("#show_investment_#{investment.id}")["href"]).to eq(investment_path(investment))
      expect(document.at_css("#edit_investment_#{investment.id}")["href"]).to eq(edit_investment_path(investment))
    end
  end

  describe "[ #show ]" do
    it "renders an ordinary investment and its context-owned generated cash projection" do
      investment = create(
        :investment,
        user:,
        context: user.main_context,
        user_bank_account:,
        investment_type:,
        description: "Treasury contribution",
        price: 12_345,
        date: Time.zone.local(2026, 8, 14, 11, 30),
        month: 8,
        year: 2026
      )
      projection = investment.cash_transaction

      get investment_path(investment)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Treasury contribution")
      expect(response.body).to include(I18n.t("dashboards.investments.kind.ordinary"))
      expect(response.body).not_to include(I18n.t("dashboards.investments.kind.valuation"))
      expect(response.body).to include(investment_type.display_name)
      expect(response.body).to include(user_bank_account.user_bank_account_name)
      expect(response.body).to include(projection.categories.first.name)
      expect(response.body).to include(projection.entities.first.entity_name)

      document = Nokogiri::HTML.fragment(response.body)
      projection_link = document.css("a").find { |link| link["href"] == cash_transaction_path(projection, return_to: investment_path(investment)) }

      expect(document.text).to include(projection.description)
      expect(projection_link).to be_present
      expect(document.css("a").map { |link| link["href"] }).to include(
        record_audit_versions_path(item_type: "Investment", item_id: investment.id),
        edit_investment_path(investment, return_to: investments_path),
        duplicate_investment_path(investment, return_to: investments_path)
      )
      expect(document.at_css("#delete_investment_#{investment.id}")).to be_present
    end

    it "renders an explicit unavailable state without recreating a missing projection" do
      investment = create(
        :investment,
        user:,
        context: user.main_context,
        user_bank_account:,
        investment_type:,
        price: 2_500,
        date: Time.zone.today,
        month: Time.zone.today.month,
        year: Time.zone.today.year
      )
      investment.update_column(:cash_transaction_id, nil)
      updated_at = investment.reload.updated_at

      expect do
        get investment_path(investment)
      end.not_to change(CashTransaction, :count)

      expect(response).to have_http_status(:success)
      expect(response.body).to include(I18n.t("dashboards.investments.projection.unavailable"))
      expect(investment.reload.updated_at).to eq(updated_at)
      expect(investment.cash_transaction_id).to be_nil
    end

    it "links to the exact account-and-type aggregation across its represented months" do
      investment = create(
        :investment,
        user:,
        context: user.main_context,
        user_bank_account:,
        investment_type:,
        description: "August treasury contribution",
        date: Time.zone.local(2026, 8, 14),
        month: 8,
        year: 2026
      )
      related_investment = create(
        :investment,
        user:,
        context: user.main_context,
        user_bank_account:,
        investment_type:,
        description: "July treasury contribution",
        date: Time.zone.local(2026, 7, 14),
        month: 7,
        year: 2026
      )
      unrelated_investment = create(
        :investment,
        user:,
        context: user.main_context,
        user_bank_account:,
        investment_type: create(:investment_type, :random),
        description: "Unrelated July contribution",
        date: Time.zone.local(2026, 7, 20),
        month: 7,
        year: 2026
      )

      get investment_path(investment)

      document = Nokogiri::HTML.fragment(response.body)
      aggregation_link = document.css("a").find { |link| link.text == I18n.t("dashboards.investments.actions.view_aggregation") }
      query = Rack::Utils.parse_nested_query(URI.parse(aggregation_link["href"]).query)

      expect(JSON.parse(query["active_month_years"])).to eq([ 202_607, 202_608 ])
      expect(query["investment"]).to eq(
        "investment_type_id" => [ investment_type.id.to_s ],
        "user_bank_account_id" => [ user_bank_account.id.to_s ]
      )
      expect(query["return_to"]).to eq(investment_path(investment))

      get month_year_investments_path, params: { month_year: "202607", investment: query["investment"], return_to: query["return_to"] }

      expect(response.body).to include(related_investment.description)
      expect(response.body).not_to include(unrelated_investment.description)
    end

    it "does not expose an investment from another active context" do
      other_context = create(:context, user:)
      other_investment = create(
        :investment,
        user:,
        context: other_context,
        user_bank_account:,
        investment_type:,
        date: Time.zone.today,
        month: Time.zone.today.month,
        year: Time.zone.today.year
      )

      get investment_path(other_investment)

      expect(response).to have_http_status(:not_found)
    end

    it "preserves an approved dashboard return destination through show actions" do
      investment = create(
        :investment,
        user:,
        context: user.main_context,
        user_bank_account:,
        investment_type:,
        date: Time.zone.today,
        month: Time.zone.today.month,
        year: Time.zone.today.year
      )
      return_to = user_bank_account_path(user_bank_account)

      get investment_path(investment), params: { return_to: }

      document = Nokogiri::HTML.fragment(response.body)
      hrefs = document.css("a").map { |link| link["href"] }

      expect(hrefs).to include(
        edit_investment_path(investment, return_to:),
        duplicate_investment_path(investment, return_to:)
      )
      confirmation = document.at_css("#linkWithConfirmDialog_#{investment.id}")

      expect(confirmation["data-confirm-href-value"]).to eq(investment_path(investment, return_to:))
    end
  end

  describe "[ #new ]" do
    it "renders the ruby ui comboboxes" do
      piggy_bank_return = create_piggy_bank_return
      piggy_bank_investment_type = create(
        :investment_type,
        investment_type_code: "outros_cofrinho",
        investment_type_name_fallback: "Outros - Cofrinho",
        built_in: true
      )

      get new_investment_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include('data-controller="form-loading"')
      expect(response.body).to include('id="investment_form_submission_skeleton"')
      expect(response.body).to include("ruby-ui--combobox")
      expect(response.body).to include('id="investment_form"')
      expect(response.body).to include('data-controller="reactive-form price-mask"')
      expect(response.body).to include('data-reactive-form-quick-jump-value="true"')
      expect(response.body).to include('data-reactive-form-target="investmentTypeCombobox"')
      expect(response.body).to include('id="investment_piggy_bank_return_combobox"')
      expect(response.body).to include("Emergency reserve")
      expect(response.body).to include("value=\"#{piggy_bank_return.id}\"")
      expect(response.body).not_to include("hw-combobox")

      document = Nokogiri::HTML.fragment(response.body)
      piggy_bank_option = document.at_css("input[name='investment[piggy_bank_return_cash_transaction_id]'][value='#{piggy_bank_return.id}']")
      expect(piggy_bank_option["data-action"]).to include("change->reactive-form#selectPiggyBankDefaults")
      expect(piggy_bank_option["data-piggy-bank-user-bank-account-id"]).to eq(piggy_bank_return.user_bank_account_id.to_s)
      expect(piggy_bank_option["data-piggy-bank-investment-type-id"]).to eq(piggy_bank_investment_type.id.to_s)
    end

    it "focuses price when using next_day" do
      get new_investment_path, params: {
        investment: {
          user_bank_account_id: user_bank_account.id,
          investment_type_id: investment_type.id
        },
        next_day: true
      }

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Duplicating")
      expect(response.body).to match(/name="chain_mode"[^>]*value="duplicate"/)
      expect(response.body).to include('name="next_day"')
      expect(response.body).to include('id="transaction_price"')
      expect(response.body).to include('data-controller="input-select autofocus"')
      expect(response.body).to include('data-autofocus-select-value="true"')
      expect(response.body).to include('data-datetime-input-target="weekdayLabel"')
      expect(response.body).not_to include('id="investment_date_time_input"')
    end
  end

  describe "[ #duplicate ]" do
    it "renders a duplicated investment form without creating a new record" do
      investment = create(
        :investment,
        user:,
        context: user.main_context,
        user_bank_account:,
        investment_type:,
        description: "Duplicated investment",
        price: 2000,
        date: Date.new(2026, 3, 14),
        month: 3,
        year: 2026
      )

      expect { get duplicate_investment_path(investment) }.not_to change(Investment, :count)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Duplicating")
      expect(response.body).to match(/name="chain_mode"[^>]*value="duplicate"/)
      expect(response.body).to include('data-controller="input-select autofocus"')

      document = Nokogiri::HTML.fragment(response.body)

      expect(document.at_css("#investment_date")["value"]).to eq("2026-03-14T00:00")
      expect(document.at_css("#investment_date_time_input")).to be_nil
    end

    it "renders destroy on the persisted edit form" do
      investment = create(
        :investment,
        user:,
        context: user.main_context,
        user_bank_account:,
        investment_type:,
        description: "Editable investment",
        price: 2000,
        date: Date.new(2026, 3, 14),
        month: 3,
        year: 2026
      )

      get edit_investment_path(investment)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("delete_investment_#{investment.id}")
      expect(response.body).to include(I18n.t("actions.destroy"))
    end
  end

  describe "[ #create ]" do
    it "creates a signed valuation linked to a Piggy Bank return" do
      piggy_bank_return = create_piggy_bank_return

      expect do
        post investments_path, params: {
          investment: {
            description: "Monthly profit",
            price: 800,
            date: Time.zone.today,
            month: Time.zone.today.month,
            year: Time.zone.today.year,
            user_id: user.id,
            user_bank_account_id: user_bank_account.id,
            investment_type_id: investment_type.id,
            piggy_bank_return_cash_transaction_id: piggy_bank_return.id
          }
        }
      end.to change(Investment, :count).by(1)

      expect(Investment.last.piggy_bank_return_cash_transaction).to eq(piggy_bank_return)
      expect(Investment.last.cash_transaction).to be_nil
      expect(piggy_bank_return.reload.price).to eq(5_800)
    end

    it "continues a create chain with the created ids tracked in the next form" do
      expect do
        post investments_path, params: {
          investment: {
            description: "Tesouro Selic",
            price: 1234,
            date: Date.new(2026, 3, 14),
            month: 3,
            year: 2026,
            user_id: user.id,
            user_bank_account_id: user_bank_account.id,
            investment_type_id: investment_type.id
          },
          chain_mode: "create",
          continue_chain: "1"
        }, headers: turbo_stream_headers
      end.to change(Investment, :count).by(1)

      created_investment = Investment.last

      expect(response).to have_http_status(:see_other)
      get URI.parse(response.location).request_uri, headers: html_headers

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Chain Creating")
      expect(response.body).to match(/name="chain_mode"[^>]*value="create"/)
      expect(response.body).to match(/name="chain_record_ids\[\]"[^>]*value="#{created_investment.id}"/)
      expect(response.body).to include('name="continue_chain" value="1"')
      expect(response.body).to include("checked")
      expect(response.body).to match(/name="investment\[user_bank_account_id\]"[^>]*value="#{user_bank_account.id}"[^>]*checked/)
      expect(response.body).to match(/name="investment\[investment_type_id\]"[^>]*value="#{investment_type.id}"[^>]*checked/)
    end

    it "shows generic and detailed failure notifications when create validation fails" do
      expect do
        post investments_path, params: {
          investment: {
            description: "",
            price: 1234,
            date: Date.new(2026, 3, 14),
            month: 3,
            year: 2026,
            user_id: user.id,
            user_bank_account_id: user_bank_account.id,
            investment_type_id: investment_type.id
          }
        }, headers: turbo_stream_headers
      end.not_to change(Investment, :count)

      expect(response.body).to include(I18n.t("notification.not_created", model: Investment.model_name.human))
      expect(response.body).to include(Investment.human_attribute_name(:description))
      expect(response.body).to include("can&#39;t be blank")
      expect(response.body).not_to include(">is invalid<")
      expect(response.body).to include('<turbo-stream action="update" target="notification">')
      expect(response.body).to include('<turbo-stream action="append" target="notification">')
    end

    it "continues a next_day duplicate chain from the newly created investment date" do
      create(
        :investment,
        user:,
        context: user.main_context,
        user_bank_account:,
        investment_type:,
        description: "Seed investment",
        price: 1000,
        date: Date.new(2026, 3, 23),
        month: 3,
        year: 2026
      )

      get new_investment_path, params: {
        investment: {
          user_bank_account_id: user_bank_account.id,
          investment_type_id: investment_type.id
        },
        next_day: true
      }

      expect(response).to have_http_status(:success)
      initial_document = Nokogiri::HTML.fragment(response.body)

      expect(initial_document.at_css("#investment_date")["value"]).to eq("2026-03-24T00:00")

      expect do
        post investments_path, params: {
          investment: {
            description: "Duplicated next day",
            price: 1234,
            date: Date.new(2026, 3, 24),
            month: 3,
            year: 2026,
            user_id: user.id,
            user_bank_account_id: user_bank_account.id,
            investment_type_id: investment_type.id,
            duplicate: true
          },
          next_day: true,
          chain_mode: "duplicate",
          continue_chain: "1"
        }, headers: turbo_stream_headers
      end.to change(Investment, :count).by(1)

      created_investment = Investment.order(:id).last

      expect(created_investment.date.to_date).to eq(Date.new(2026, 3, 24))
      expect(response).to have_http_status(:see_other)
      get URI.parse(response.location).request_uri, headers: html_headers

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Chain Duplicating")

      next_document = Nokogiri::HTML.fragment(response.body)

      expect(next_document.at_css("#investment_date")["value"]).to eq("2026-03-25T00:00")
      expect(response.body).to match(/name="chain_mode"[^>]*value="duplicate"/)
      expect(response.body).to include('name="next_day"')
    end

    it "finishes a chain without saving the current investment form" do
      existing_investment = create(
        :investment,
        user:,
        context: user.main_context,
        user_bank_account: user_bank_account,
        investment_type: investment_type,
        description: "Existing chained investment",
        price: 1234,
        date: Date.new(2026, 3, 14),
        month: 3,
        year: 2026
      )

      expect do
        post investments_path, params: {
          chain_mode: "create",
          chain_record_ids: [ existing_investment.id ],
          finish_chain_without_save: "1",
          investment: {
            description: "",
            price: "",
            date: "",
            user_id: user.id,
            user_bank_account_id: user_bank_account.id,
            investment_type_id: investment_type.id
          }
        }, headers: turbo_stream_headers
      end.not_to change(Investment, :count)

      expect(response).to have_http_status(:see_other)
      destination = URI.parse(response.location).request_uri
      expect(destination).to include("investment%5Buser_bank_account_id%5D", "investment%5Binvestment_type_id%5D", "202603")
      expect(destination).not_to include("investment%5Bid%5D")
    end

    it "shows every investment in the duplicated account, type, and reference month" do
      existing_investment = create(
        :investment,
        user:,
        context: user.main_context,
        user_bank_account:,
        investment_type:,
        description: "Existing grouped investment",
        price: 1000,
        date: Date.new(2026, 3, 10),
        month: 3,
        year: 2026
      )

      post investments_path, params: {
        chain_mode: "duplicate",
        investment: {
          description: "New grouped investment",
          price: 1200,
          date: Date.new(2026, 3, 14),
          month: 3,
          year: 2026,
          user_id: user.id,
          user_bank_account_id: user_bank_account.id,
          investment_type_id: investment_type.id
        }
      }, headers: turbo_stream_headers

      expect(response).to have_http_status(:see_other)
      expect(response.location).to include("investment%5Buser_bank_account_id%5D", "investment%5Binvestment_type_id%5D")
      expect(response.location).not_to include("investment%5Bid%5D")

      get URI.parse(response.location).request_uri, headers: html_headers

      document = Nokogiri::HTML.fragment(response.body)
      frame_path = document.at_css("#month_year_container_202603")["src"]
      get frame_path, headers: html_headers

      expect(response.body).to include(existing_investment.description, "New grouped investment")
    end

    it "shows every valuation for the duplicated Piggy Bank return and reference month" do
      piggy_bank_return = create_piggy_bank_return
      other_piggy_bank_return = create_piggy_bank_return
      existing_valuation = create(
        :investment,
        user:,
        context: user.main_context,
        user_bank_account:,
        investment_type:,
        piggy_bank_return_cash_transaction: piggy_bank_return,
        description: "Existing Piggy Bank valuation",
        price: 500,
        date: Date.new(2026, 3, 10),
        month: 3,
        year: 2026
      )
      create(
        :investment,
        user:,
        context: user.main_context,
        user_bank_account:,
        investment_type:,
        piggy_bank_return_cash_transaction: other_piggy_bank_return,
        description: "Other Piggy Bank valuation",
        price: 400,
        date: Date.new(2026, 3, 10),
        month: 3,
        year: 2026
      )

      post investments_path, params: {
        chain_mode: "duplicate",
        investment: {
          description: "New Piggy Bank valuation",
          price: 300,
          date: Date.new(2026, 3, 14),
          month: 3,
          year: 2026,
          user_id: user.id,
          user_bank_account_id: user_bank_account.id,
          investment_type_id: investment_type.id,
          piggy_bank_return_cash_transaction_id: piggy_bank_return.id
        }
      }, headers: turbo_stream_headers

      expect(response).to have_http_status(:see_other)
      expect(response.location).to include("investment%5Bpiggy_bank_return_cash_transaction_id%5D")
      expect(response.location).not_to include("investment%5Bid%5D", "investment%5Buser_bank_account_id%5D", "investment%5Binvestment_type_id%5D")

      get URI.parse(response.location).request_uri, headers: html_headers

      document = Nokogiri::HTML.fragment(response.body)
      frame_path = document.at_css("#month_year_container_202603")["src"]
      expect(frame_path).to include(piggy_bank_return.id.to_s)

      get frame_path, headers: html_headers

      row_text = Nokogiri::HTML.fragment(response.body).css("[data-datatable-target='row']").map(&:text).join(" ")

      expect(row_text).to include(existing_valuation.description, "New Piggy Bank valuation")
      expect(row_text).not_to include("Other Piggy Bank valuation")
    end

    it "creates an investment" do
      expect do
        post investments_path, params: {
          investment: {
            description: "Tesouro Selic",
            price: 1234,
            date: Date.new(2026, 3, 14),
            month: 3,
            year: 2026,
            user_id: user.id,
            user_bank_account_id: user_bank_account.id,
            investment_type_id: investment_type.id
          }
        }, headers: turbo_stream_headers
      end.to change(Investment, :count).by(1)

      expect(response).to have_http_status(:see_other)
      expect(response).to redirect_to(investments_path)
    end
  end

  describe "[ #update ]" do
    it "updates the record" do
      investment = create(:investment, user:, user_bank_account:, investment_type:)

      patch investment_path(investment), params: {
        investment: {
          description: "Updated Investment",
          price: investment.price,
          date: investment.date,
          month: investment.month,
          year: investment.year,
          user_id: user.id,
          user_bank_account_id: user_bank_account.id,
          investment_type_id: investment_type.id
        }
      }, headers: turbo_stream_headers

      expect(investment.reload.description).to eq("Updated Investment")
      expect(response).to have_http_status(:see_other)
      expect(response).to redirect_to(investments_path)
    end

    it "shows generic and detailed failure notifications when update validation fails" do
      investment = create(:investment, user:, user_bank_account:, investment_type:)

      patch investment_path(investment), params: {
        investment: {
          description: "",
          price: investment.price,
          date: investment.date,
          month: investment.month,
          year: investment.year,
          user_id: user.id,
          user_bank_account_id: user_bank_account.id,
          investment_type_id: investment_type.id
        }
      }, headers: turbo_stream_headers

      expect(response.body).to include(I18n.t("notification.not_updated", model: Investment.model_name.human))
      expect(response.body).to include(Investment.human_attribute_name(:description))
      expect(response.body).to include("can&#39;t be blank")
      expect(response.body).not_to include(">is invalid<")
      expect(response.body).to include('<turbo-stream action="update" target="notification">')
      expect(response.body).to include('<turbo-stream action="append" target="notification">')
    end
  end

  describe "[ #destroy ]" do
    it "destroys the record" do
      investment = create(:investment, user:, user_bank_account:, investment_type:)

      expect do
        delete investment_path(investment), headers: turbo_stream_headers
      end.to change(Investment, :count).by(-1)
    end
  end

  describe "[ #month_year ]" do
    it "renders successfully" do
      investment = create(:investment, user:, user_bank_account:, investment_type:, month: 3, year: 2026, date: Date.new(2026, 3, 14))
      presentation = CategoryColours::Presentation.for(user.built_in_category("INVESTMENT"))

      get month_year_investments_path, params: { month_year: "202603" }

      expect(response).to have_http_status(:success)
      document = Nokogiri::HTML.fragment(response.body)
      row = document.at_css("[data-datatable-target='row'][data-id='#{investment.id}']")
      expect(row["style"]).to include("background-color: #{presentation.background}", "color: #{presentation.foreground}")
      expect(row["class"]).not_to include("hover:opacity")
    end
  end

  describe "[ context isolation ]" do
    it "keeps create, update, and destroy changes inside the derived context" do
      main_investment = create(
        :investment,
        user:,
        context: user.main_context,
        user_bank_account:,
        investment_type:,
        description: "Main isolated investment",
        price: 1234,
        date: Date.new(2026, 3, 14)
      )

      derived_context = Logic::ContextCloneService.new(
        source_context: user.main_context,
        name: "Investment Isolation"
      ).call
      derived_investment = derived_context.investments.find_by!(description: main_investment.description)

      switch_to_context!(derived_context)

      expect do
        post investments_path, params: {
          investment: {
            description: "Derived only investment",
            price: 5678,
            date: Date.new(2026, 4, 14),
            month: 4,
            year: 2026,
            user_id: user.id,
            user_bank_account_id: user_bank_account.id,
            investment_type_id: investment_type.id
          }
        }, headers: turbo_stream_headers
      end.to change { derived_context.investments.reload.count }.by(1)

      expect(user.main_context.investments.reload.count).to eq(1)

      patch investment_path(derived_investment), params: {
        investment: {
          description: "Derived updated investment",
          price: derived_investment.price,
          date: derived_investment.date,
          month: derived_investment.month,
          year: derived_investment.year,
          user_id: user.id,
          user_bank_account_id: user_bank_account.id,
          investment_type_id: investment_type.id
        }
      }, headers: turbo_stream_headers

      expect(derived_investment.reload.description).to eq("Derived updated investment")
      expect(main_investment.reload.description).to eq("Main isolated investment")

      expect do
        delete investment_path(derived_investment), headers: turbo_stream_headers
      end.to change { derived_context.investments.reload.count }.by(-1)

      expect(user.main_context.investments.reload.count).to eq(1)

      expect(Investment.exists?(main_investment.id)).to be(true)
    end
  end

  describe "[ cross-context access denial ]" do
    it "does not allow editing, updating, or destroying a main-context investment while in a derived context" do
      main_investment = create(
        :investment,
        user:,
        context: user.main_context,
        user_bank_account:,
        investment_type:,
        description: "Main inaccessible investment"
      )

      derived_context = Logic::ContextCloneService.new(
        source_context: user.main_context,
        name: "Investment Access Isolation"
      ).call

      switch_to_context!(derived_context)

      get edit_investment_path(main_investment)
      expect(response).to have_http_status(:not_found)

      patch investment_path(main_investment), params: {
        investment: {
          description: "Should not update",
          price: main_investment.price,
          date: main_investment.date,
          month: main_investment.month,
          year: main_investment.year,
          user_id: user.id,
          user_bank_account_id: user_bank_account.id,
          investment_type_id: investment_type.id
        }
      }, headers: turbo_stream_headers
      expect(response).to have_http_status(:not_found)

      delete investment_path(main_investment), headers: turbo_stream_headers
      expect(response).to have_http_status(:not_found)
    end
  end
end
