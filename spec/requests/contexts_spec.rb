# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Contexts", type: :request do
  let(:user) { create(:user, :random) }

  before { sign_in user }

  describe "[ #index ]" do
    it "renders the tree page" do
      get contexts_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Contexts")
    end

    it "renders nested contexts and create-child entrypoints for each node" do
      child_context = create(:context, user:, name: "Optimistic", source_context: user.main_context)
      grandchild_context = create(:context, user:, name: "Vacation", source_context: child_context)

      get contexts_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(user.main_context.name)
      expect(response.body).to include("Optimistic")
      expect(response.body).to include("Vacation")
      expect(response.body).to include(new_context_path(source_context_id: user.main_context.id))
      expect(response.body).to include(new_context_path(source_context_id: child_context.id))
      expect(response.body).to include(new_context_path(source_context_id: grandchild_context.id))
      expect(response.body).to include(context_path(child_context))
      expect(response.body).to include(context_path(grandchild_context))
    end
  end

  describe "[ #new ]" do
    it "renders the clone form for a source context" do
      get new_context_path(source_context_id: user.main_context.id)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Create Context")
      expect(response.body).to include(user.main_context.name)
    end
  end

  describe "[ #create ]" do
    it "creates a derived context from the selected source context" do
      post contexts_path, params: {
        context: {
          source_context_id: user.main_context.id,
          name: "Scenario Clone",
          description: "What if branch"
        }
      }

      created_context = user.contexts.find_by!(name: "Scenario Clone")

      expect(created_context.source_context).to eq(user.main_context)
      expect(created_context).not_to be_main
      expect(response).to redirect_to(context_path(created_context))
    end

    it "creates a child context from a derived parent node" do
      parent_context = create(:context, user:, name: "Optimistic", source_context: user.main_context)

      post contexts_path, params: {
        context: {
          source_context_id: parent_context.id,
          name: "Vacation plan",
          description: "Nested branch"
        }
      }

      created_context = user.contexts.find_by!(name: "Vacation plan")

      expect(created_context.source_context).to eq(parent_context)
      expect(response).to redirect_to(context_path(created_context))
    end
  end

  describe "[ #show ]" do
    it "renders the context modal page" do
      scenario_context = create(:context, user:, name: "Scenario A")

      get context_path(scenario_context)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Scenario A")
    end

    it "renders switch and create-child actions for derived contexts" do
      scenario_context = create(:context, user:, name: "Scenario A", source_context: user.main_context)

      get context_path(scenario_context)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(new_context_path(source_context_id: scenario_context.id))
      expect(response.body).to include(switch_context_path(scenario_context))
    end
  end

  describe "[ #switch ]" do
    it "stores the selected context in session" do
      scenario_context = create(:context, user:, name: "Scenario A")

      patch switch_context_path(scenario_context)

      expect(session[:current_context_id]).to eq(scenario_context.id)
      expect(response).to redirect_to(root_path)
    end

    it "keeps the selected context active on the next financial month-year page" do
      scenario_context = create(:context, user:, name: "Scenario A", source_context: user.main_context)
      bank = create(:bank, :random)
      user_bank_account = create(:user_bank_account, user:, bank:)
      month_year = 202_603

      create(
        :cash_transaction,
        user:,
        context: user.main_context,
        user_bank_account:,
        description: "Main only transaction",
        date: Date.new(2026, 3, 10),
        month: 3,
        year: 2026
      )
      create(
        :cash_transaction,
        user:,
        context: scenario_context,
        user_bank_account:,
        description: "Derived only transaction",
        date: Date.new(2026, 3, 10),
        month: 3,
        year: 2026
      )

      patch switch_context_path(scenario_context)
      follow_redirect!
      get month_year_cash_transactions_path, params: {
        month_year:,
        cash_transaction: { user_bank_account_id: user_bank_account.id }
      }

      expect(session[:current_context_id]).to eq(scenario_context.id)
      expect(response.body).to include("Derived only transaction")
      expect(response.body).not_to include("Main only transaction")
    end

    it "does not allow switching to another user's context" do
      foreign_context = create(:context, user: create(:user, :random), name: "Foreign")

      patch switch_context_path(foreign_context)

      expect(response).to have_http_status(:not_found)
    end
  end
end
