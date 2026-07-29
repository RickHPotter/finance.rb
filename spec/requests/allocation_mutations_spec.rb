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
    expect(response.body).to include('target="allocation_mutation_preview"', 'target="notification"')

    post apply_allocation_mutations_path,
         params: { apply_token: "#{token}tampered", mode: "strict", allocation_confirmation: "1" },
         headers: { "Accept" => "text/vnd.turbo-stream.html" }

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include(I18n.t("allocation_mutations.apply.reasons.invalid_token"))
  end
end
