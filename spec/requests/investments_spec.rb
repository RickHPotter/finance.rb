# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Investments", type: :request do
  let(:user) { create(:user, :random) }
  let(:bank) { create(:bank, :random) }
  let(:user_bank_account) { create(:user_bank_account, :random, user:, bank:) }
  let(:investment_type) { create(:investment_type, :random) }

  before { sign_in user }

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
  end

  describe "[ #new ]" do
    it "renders the ruby ui comboboxes" do
      get new_investment_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include('data-controller="form-loading"')
      expect(response.body).to include('id="investment_form_submission_skeleton"')
      expect(response.body).to include("ruby-ui--combobox")
      expect(response.body).to include('id="investment_form"')
      expect(response.body).to include('data-controller="reactive-form price-mask"')
      expect(response.body).to include('data-reactive-form-quick-jump-value="true"')
      expect(response.body).to include('data-reactive-form-target="investmentTypeCombobox"')
      expect(response.body).not_to include("hw-combobox")
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

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Chain Creating")
      expect(response.body).to match(/name="chain_mode"[^>]*value="create"/)
      expect(response.body).to match(/name="chain_record_ids\[\]"[^>]*value="#{created_investment.id}"/)
      expect(response.body).to include('name="continue_chain" value="1"')
      expect(response.body).to include("checked")
      expect(response.body).to match(/name="investment\[user_bank_account_id\]"[^>]*value="#{user_bank_account.id}"[^>]*checked/)
      expect(response.body).to match(/name="investment\[investment_type_id\]"[^>]*value="#{investment_type.id}"[^>]*checked/)
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

      expect(response).to have_http_status(:success)
      expect(response.body).not_to include("investment%5Bid%5D")
      expect(response.body).to include("investment%5Buser_bank_account_id%5D%5B%5D=#{user_bank_account.id}")
      expect(response.body).to include("investment%5Binvestment_type_id%5D%5B%5D=#{investment_type.id}")
      expect(response.body).to include("202603")
      expect(response.body).not_to include("Chain Creating")
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

      expect(response.body).not_to include("investment%5Bid%5D")
      expect(response.body).to include("investment%5Buser_bank_account_id%5D%5B%5D=#{user_bank_account.id}")
      expect(response.body).to include("investment%5Binvestment_type_id%5D%5B%5D=#{investment_type.id}")
      expect(response.body).to include("202603")
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
      expect(response.body).not_to include("investment%5Bid%5D")
      expect(response.body).to include("investment%5Buser_bank_account_id%5D%5B%5D=#{user_bank_account.id}")
      expect(response.body).to include("investment%5Binvestment_type_id%5D%5B%5D=#{investment_type.id}")
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
      create(:investment, user:, user_bank_account:, investment_type:, month: 3, year: 2026, date: Date.new(2026, 3, 14))

      get month_year_investments_path, params: { month_year: "202603" }

      expect(response).to have_http_status(:success)
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
