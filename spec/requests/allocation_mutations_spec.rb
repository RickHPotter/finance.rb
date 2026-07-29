# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Allocation mutations" do
  let(:user) { create(:user) }
  let(:context) { user.main_context }
  let(:destination) { create(:category, user:, category_name: "DESTINATION") }
  let(:transaction) do
    create(
      :cash_transaction,
      user:,
      context:,
      description: "Allocation request",
      user_bank_account: create(:user_bank_account, :random, user:),
      category_transactions: []
    )
  end
  let(:preview_params) do
    {
      allocation_mutation: {
        owner_type: "CashTransaction",
        owner_ids: [ transaction.id ],
        selected_row_count: 2,
        return_to: cash_transactions_path,
        action: {
          allocation_type: "category",
          operation: "add",
          destination_id: destination.id
        }
      }
    }
  end

  before { sign_in user }

  it "renders a non-mutating HTML preview with signed strict apply controls" do
    preview_params
    operation_count = AuditOperation.count

    expect do
      post preview_allocation_mutations_path, params: preview_params
    end.not_to change(CategoryTransaction, :count)

    expect(response).to have_http_status(:ok)
    expect(AuditOperation.count).to eq(operation_count)
    document = Nokogiri::HTML5(response.body)
    expect(document.at_css("turbo-frame#allocation_mutation_preview")).to be_present
    expect(document.at_css("form[action='#{apply_allocation_mutations_path}']")).to be_present
    expect(document.at_css("input[name='apply_token']")["value"]).to be_present
    expect(document.at_css("input[name='mode']")["value"]).to eq("strict")
    expect(response.body).to include("2", "1", destination.name)
  end

  it "supports Turbo and JSON preview responders with the same server result" do
    post preview_allocation_mutations_path, params: preview_params, headers: { "Accept" => "text/vnd.turbo-stream.html" }

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("text/vnd.turbo-stream.html")
    expect(response.body).to include('target="allocation_mutation_preview"')

    post preview_allocation_mutations_path, params: preview_params, as: :json

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to include(
      "selected_row_count" => 2,
      "unique_owner_count" => 1,
      "affected_count" => 1,
      "strict_apply_available" => true
    )
  end

  it "renders the shared allocation launcher on Cash and Card transaction indexes" do
    user_card = create(:user_card, user:)

    get cash_transactions_path

    expect(response).to have_http_status(:ok)
    cash_document = Nokogiri::HTML5(response.body)
    expect(cash_document.at_css("##{Components::AllocationMutationInterface.modal_id('installment')}")).to be_present
    cash_launcher = cash_document.at_css("[data-modal-target='#{Components::AllocationMutationInterface.modal_id('installment')}']")
    expect(cash_launcher).to be_present
    expect(cash_launcher["data-allocation-mutation-launch"]).to eq("true")

    get card_transactions_path(user_card_id: user_card.id)

    expect(response).to have_http_status(:ok)
    card_document = Nokogiri::HTML5(response.body)
    expect(card_document.at_css("##{Components::AllocationMutationInterface.modal_id('installment')}")).to be_present
    card_launcher = card_document.at_css("[data-modal-target='#{Components::AllocationMutationInterface.modal_id('installment')}']")
    expect(card_launcher).to be_present
    expect(card_launcher["data-allocation-mutation-launch"]).to eq("true")
  end

  it "counts repeated selected installments once as a paid CardTransaction owner" do
    user_card = create(:user_card, user:)
    card_transaction = create(
      :card_transaction,
      user:,
      context:,
      user_card:,
      category_transactions: []
    )
    card_transaction.card_installments.first.update_column(:paid, true)

    post preview_allocation_mutations_path, params: {
      allocation_mutation: {
        owner_type: "CardTransaction",
        owner_ids: [ card_transaction.id, card_transaction.id ],
        selected_row_count: 2,
        action: {
          allocation_type: "category",
          operation: "add",
          destination_id: destination.id
        }
      }
    }, as: :json

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to include(
      "selected_row_count" => 2,
      "unique_owner_count" => 1,
      "affected_count" => 1
    )
  end

  it "does not reveal owners outside the current context" do
    foreign_user = create(:user, :random)
    foreign = create(
      :cash_transaction,
      user: foreign_user,
      context: foreign_user.main_context,
      user_bank_account: create(:user_bank_account, :random, user: foreign_user)
    )
    preview_params[:allocation_mutation][:owner_ids] = [ foreign.id ]

    post preview_allocation_mutations_path, params: preview_params

    expect(response).to have_http_status(:not_found)
    expect(foreign.reload.categories).not_to include(destination)
  end

  it "applies through Post/Redirect/Get to the canonical owner index" do
    post preview_allocation_mutations_path, params: preview_params
    token = Nokogiri::HTML5(response.body).at_css("input[name='apply_token']")["value"]

    post apply_allocation_mutations_path, params: {
      apply_token: token,
      mode: "strict",
      allocation_confirmation: "1",
      return_to: cash_transactions_path
    }

    expect(response).to redirect_to(cash_transactions_path)
    expect(response).to have_http_status(:see_other)
    expect(transaction.reload.categories).to contain_exactly(destination)
  end

  it "keeps Turbo apply on the workflow and returns detailed failure status" do
    post preview_allocation_mutations_path, params: preview_params, as: :json
    token = response.parsed_body.fetch("apply_token")

    post apply_allocation_mutations_path,
         params: { apply_token: token, mode: "strict", allocation_confirmation: "1" },
         headers: { "Accept" => "text/vnd.turbo-stream.html" }

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("text/vnd.turbo-stream.html")
    expect(response.body).to include('target="center_container"', 'target="notification"')
    expect(response.body).to include(Components::AllocationMutationInterface.modal_id("installment"))

    post apply_allocation_mutations_path,
         params: { apply_token: "#{token}tampered", mode: "strict", allocation_confirmation: "1" },
         headers: { "Accept" => "text/vnd.turbo-stream.html" }

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include('target="allocation_mutation_preview"')
    expect(response.body).to include(I18n.t("allocation_mutations.apply.reasons.invalid_token"))
  end

  it "refreshes the selected Card index state after Turbo apply without changing its URL" do
    user_card = create(:user_card, user:)
    card_transaction = create(
      :card_transaction,
      user:,
      context:,
      user_card:,
      category_transactions: []
    )
    return_to = card_transactions_path(user_card_id: user_card.id, active_month_years: [ 202_607 ], sort: "description", direction: "desc")
    post preview_allocation_mutations_path, params: {
      allocation_mutation: {
        owner_type: "CardTransaction",
        owner_ids: [ card_transaction.id ],
        selected_row_count: 1,
        return_to:,
        action: {
          allocation_type: "category",
          operation: "add",
          destination_id: destination.id
        }
      }
    }, as: :json
    token = response.parsed_body.fetch("apply_token")

    post apply_allocation_mutations_path,
         params: { apply_token: token, mode: "strict", allocation_confirmation: "1", return_to: },
         headers: { "Accept" => "text/vnd.turbo-stream.html" }

    expect(response).to have_http_status(:ok)
    expect(response.location).to be_nil
    expect(response.body).to include('target="center_container"', CGI.escapeHTML(return_to))
    expect(card_transaction.reload.categories).to contain_exactly(destination)
  end

  it "renders isolated Budget allocation controls on both Budget surfaces" do
    get budgets_path

    expect(response).to have_http_status(:ok)
    budget_document = Nokogiri::HTML5(response.body)
    budget_modal_id = Components::AllocationMutationInterface.modal_id("budget")
    budget_modal = budget_document.at_css("##{budget_modal_id}")
    expect(budget_modal).to be_present
    expect(budget_modal.at_css("input[name='allocation_mutation[owner_type]']")["value"]).to eq("Budget")
    expect(budget_document.at_css("[data-modal-target='#{budget_modal_id}'][data-bulk-selection-kind='budget']")).to be_present

    get cash_transactions_path

    expect(response).to have_http_status(:ok)
    cash_document = Nokogiri::HTML5(response.body)
    expect(cash_document.at_css("##{budget_modal_id}")).to be_present
    expect(cash_document.at_css("##{Components::AllocationMutationInterface.modal_id('installment')}")).to be_present
  end

  it "refreshes a filtered Budget index after applying a criteria switch" do
    source = create(:category, user:, category_name: "SOURCE")
    budget = create(
      :budget,
      user:,
      context:,
      year: 2026,
      month: 7,
      budget_categories: [ build(:budget_category, category: source) ]
    )
    return_to = budgets_path(
      active_month_years: [ 202_607 ],
      search_term: budget.description,
      budget: { category_id: [ source.id ] }
    )
    post preview_allocation_mutations_path, params: {
      allocation_mutation: {
        owner_type: "Budget",
        owner_ids: [ budget.id ],
        selected_row_count: 1,
        return_to:,
        action: {
          allocation_type: "category",
          operation: "switch",
          source_id: source.id,
          destination_id: destination.id
        }
      }
    }, as: :json
    token = response.parsed_body.fetch("apply_token")

    post apply_allocation_mutations_path,
         params: { apply_token: token, mode: "strict", allocation_confirmation: "1", return_to: },
         headers: { "Accept" => "text/vnd.turbo-stream.html" }

    expect(response).to have_http_status(:ok)
    expect(response.location).to be_nil
    expect(response.body).to include(
      'target="center_container"',
      Components::AllocationMutationInterface.modal_id("budget"),
      CGI.escapeHTML(return_to)
    )
    expect(budget.reload.categories).to contain_exactly(destination)
  end

  it "returns an embedded Budget apply to the filtered Cash index for Turbo and HTML" do
    source = create(:category, user:, category_name: "EMBEDDED SOURCE")
    budget = create(
      :budget,
      user:,
      context:,
      year: 2026,
      month: 7,
      budget_categories: [ build(:budget_category, category: source) ]
    )
    return_to = cash_transactions_path(active_month_years: [ 202_607 ], skip_budgets: "0")
    post preview_allocation_mutations_path, params: {
      allocation_mutation: {
        owner_type: "Budget",
        owner_ids: [ budget.id ],
        selected_row_count: 1,
        return_to:,
        action: {
          allocation_type: "category",
          operation: "add",
          destination_id: destination.id
        }
      }
    }, as: :json
    token = response.parsed_body.fetch("apply_token")

    post apply_allocation_mutations_path,
         params: { apply_token: token, mode: "strict", allocation_confirmation: "1", return_to: },
         headers: { "Accept" => "text/vnd.turbo-stream.html" }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(
      'target="center_container"',
      Components::AllocationMutationInterface.modal_id("budget"),
      Components::AllocationMutationInterface.modal_id("installment"),
      CGI.escapeHTML(return_to)
    )

    post apply_allocation_mutations_path,
         params: { apply_token: token, mode: "strict", allocation_confirmation: "1", return_to: }

    expect(response).to redirect_to(return_to)
    expect(response).to have_http_status(:see_other)
    expect(budget.reload.categories).to contain_exactly(source, destination)
  end
end
