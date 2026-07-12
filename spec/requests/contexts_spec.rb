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
      expect(response.body).to include('id="context_overlay"')
      expect(response.body).to include('id="theme_toggle"')
      expect(response.body).to include('data-controller="theme"')
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
      expect(response.body).to include(I18n.t("gerund.new"))
      expect(response.body).to include(action_message(:submit))
      expect(response.body).to include(user.main_context.name)
      expect(response.body).to include('id="context_overlay"')
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
      expect(response.body).to include('id="context_overlay"')
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

    it "redirects to conversations index with a notice when switching from conversation show" do
      other_user = create(:user, :random)
      scenario_context = create(:context, user:, name: "Scenario A", source_context: user.main_context)
      conversation = Conversation.find_or_create_human_between!(user, other_user)

      patch switch_context_path(scenario_context), headers: { "HTTP_REFERER" => conversation_path(conversation) }

      expect(session[:current_context_id]).to eq(scenario_context.id)
      expect(response).to redirect_to(conversations_path)
      expect(flash[:notice]).to eq(I18n.t("contexts.switch.redirected_to_index"))
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

  describe "[ #archive ]" do
    it "archives a derived context and resets the session to main when it was active" do
      scenario_context = create(:context, user:, name: "Scenario A", source_context: user.main_context)

      patch switch_context_path(scenario_context)
      patch archive_context_path(scenario_context)

      expect(response).to redirect_to(contexts_path)
      expect(scenario_context.reload.archived_at).to be_present
      expect(session[:current_context_id]).to eq(user.main_context.id)
      expect(flash[:notice]).to eq(I18n.t("contexts.archive.success"))
    end

    it "does not archive the main context" do
      patch archive_context_path(user.main_context)

      expect(response).to redirect_to(contexts_path)
      expect(user.main_context.reload.archived_at).to be_nil
      expect(flash[:alert]).to eq(I18n.t("contexts.archive.main_forbidden"))
    end

    it "keeps archived contexts visible on index and removes them from the footer switcher" do
      archived_context = create(:context, user:, name: "Scenario A", source_context: user.main_context, archived_at: Time.current)

      get contexts_path

      expect(response.body).to include("Scenario A")
      expect(response.body).to include(I18n.t("contexts.index.archived"))
      expect(response.body).not_to include(switch_context_path(archived_context))
    end
  end

  describe "[ #unarchive ]" do
    it "restores an archived derived context" do
      archived_context = create(:context, user:, name: "Scenario A", source_context: user.main_context, archived_at: Time.current)

      patch unarchive_context_path(archived_context)

      expect(response).to redirect_to(contexts_path)
      expect(archived_context.reload.archived_at).to be_nil
      expect(flash[:notice]).to eq(I18n.t("contexts.unarchive.success"))
    end

    it "shows the restore action for archived derived contexts" do
      archived_context = create(:context, user:, name: "Scenario A", source_context: user.main_context, archived_at: Time.current)

      get context_path(archived_context)

      expect(response.body).to include(unarchive_context_path(archived_context))
      expect(response.body).to include(I18n.t("contexts.show.unarchive"))
    end
  end

  describe "[ #destroy ]" do
    it "removes an archived leaf derived context" do
      archived_context = create(:context, user:, name: "Scenario A", source_context: user.main_context, archived_at: Time.current)

      expect do
        delete context_path(archived_context)
      end.to change { user.contexts.exists?(archived_context.id) }.from(true).to(false)

      expect(response).to redirect_to(contexts_path)
      expect(flash[:notice]).to eq(I18n.t("contexts.destroy.success"))
    end

    it "does not remove an active derived context" do
      scenario_context = create(:context, user:, name: "Scenario A", source_context: user.main_context)

      expect do
        delete context_path(scenario_context)
      end.not_to change(Context, :count)

      expect(response).to redirect_to(context_path(scenario_context))
      expect(flash[:alert]).to eq(I18n.t("contexts.destroy.archive_required"))
    end

    it "does not remove the main context" do
      expect do
        delete context_path(user.main_context)
      end.not_to change(Context, :count)

      expect(response).to redirect_to(contexts_path)
      expect(flash[:alert]).to eq(I18n.t("contexts.destroy.main_forbidden"))
    end

    it "does not remove an archived context that still has child contexts" do
      archived_parent = create(:context, user:, name: "Scenario A", source_context: user.main_context, archived_at: Time.current)
      create(:context, user:, name: "Scenario B", source_context: archived_parent, archived_at: Time.current)

      expect do
        delete context_path(archived_parent)
      end.not_to change(Context, :count)

      expect(response).to redirect_to(context_path(archived_parent))
      expect(flash[:alert]).to eq(I18n.t("contexts.destroy.has_children"))
    end

    it "shows the destroy action only for archived leaf derived contexts" do
      archived_leaf = create(:context, user:, name: "Scenario A", source_context: user.main_context, archived_at: Time.current)
      archived_parent = create(:context, user:, name: "Scenario B", source_context: user.main_context, archived_at: Time.current)
      create(:context, user:, name: "Scenario C", source_context: archived_parent, archived_at: Time.current)

      get context_path(archived_leaf)
      expect(response.body).to include("delete_context_#{archived_leaf.id}")
      expect(response.body).to include(I18n.t("contexts.show.destroy"))

      get context_path(archived_parent)
      expect(response.body).not_to include("delete_context_#{archived_parent.id}")
    end

    it "removes an archived context even when contained card transactions would normally block destruction" do
      archived_context = create(:context, user:, name: "Scenario A", source_context: user.main_context, archived_at: Time.current)
      user_card = create(:user_card, user:)
      create(:card_transaction, user:, context: archived_context, user_card:)

      allow_any_instance_of(CardTransaction).to receive(:destroy_locked_by_history?).and_return(true)

      expect do
        delete context_path(archived_context)
      end.to change { user.contexts.exists?(archived_context.id) }.from(true).to(false)

      expect(response).to redirect_to(contexts_path)
      expect(flash[:notice]).to eq(I18n.t("contexts.destroy.success"))
    end

    it "does not remove an archived context when main-context records still reference it" do
      archived_context = create(:context, user:, name: "Scenario A", source_context: user.main_context, archived_at: Time.current)
      derived_cash_transaction = create(:cash_transaction, user:, context: archived_context,
                                                           user_bank_account: create(:user_bank_account, user:, bank: create(:bank, :random)))
      create(
        :cash_transaction,
        user:,
        context: user.main_context,
        user_bank_account: create(:user_bank_account, user:, bank: create(:bank, :random)),
        reference_transactable: derived_cash_transaction
      )

      expect do
        delete context_path(archived_context)
      end.not_to change(Context, :count)

      expect(response).to redirect_to(context_path(archived_context))
      expect(flash[:alert]).to eq(I18n.t("contexts.destroy.cross_context_dependencies"))
    end
  end

  describe "[ #dismiss ]" do
    it "renders an empty overlay frame" do
      get dismiss_contexts_path

      expect(response).to have_http_status(:ok)
      expect(response.body.strip).to eq('<turbo-frame id="context_overlay"></turbo-frame>')
    end
  end
end
