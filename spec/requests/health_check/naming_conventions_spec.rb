# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Health Check Naming Convention maintenance", type: :request do
  let(:admin) { create(:user, :random, admin: true) }

  it "requires authentication" do
    get preview_healthcheck_naming_convention_path

    expect(response).to redirect_to(new_user_session_path)
  end

  it "returns not found for every ordinary-user endpoint" do
    user = create(:user, :random)
    sign_in user

    get preview_healthcheck_naming_convention_path
    expect(response).to have_http_status(:not_found)

    post preview_healthcheck_naming_convention_path
    expect(response).to have_http_status(:not_found)

    patch healthcheck_naming_convention_path
    expect(response).to have_http_status(:not_found)
  end

  it "renders a read-only signed preview without creating audit history" do
    transaction = create_naming_candidate
    original_description = transaction.description
    sign_in admin

    expect do
      get preview_healthcheck_naming_convention_path
    end.to change(AuditOperation, :count).by(0).and change(AuditVersion, :count).by(0)

    document = Nokogiri::HTML.fragment(response.body)
    expect(response).to have_http_status(:ok)
    expect(transaction.reload.description).to eq(original_description)
    expect(document.at_css("turbo-frame#healthcheck_naming_convention_content")).to be_present
    expect(document.at_css("input#healthcheck_naming_convention_apply_token")["value"]).to be_present
    expect(document.at_css("input[name='naming_confirmation'][type='checkbox']")).to be_present
    expect(document.at_css("form[action='#{healthcheck_naming_convention_path}'][method='post'] input[name='_method'][value='patch']")).to be_present
    expect(response.body).to include("lazy-tabs")
    expect(response.body).not_to include("naming-tabs", "settings_")
  end

  it "supports refreshing the dry-run preview through POST without mutation" do
    transaction = create_naming_candidate
    original_description = transaction.description
    sign_in admin

    expect do
      post preview_healthcheck_naming_convention_path
    end.to change(AuditOperation, :count).by(0).and change(AuditVersion, :count).by(0)

    expect(response).to have_http_status(:ok)
    expect(transaction.reload.description).to eq(original_description)
  end

  it "rejects apply without explicit confirmation" do
    transaction = create_naming_candidate
    original_description = transaction.description
    sign_in admin
    token = preview_token

    expect do
      patch healthcheck_naming_convention_path, params: { apply_token: token }
    end.to change(AuditOperation, :count).by(0).and change(AuditVersion, :count).by(0)

    expect(response).to have_http_status(:unprocessable_content)
    expect(transaction.reload.description).to eq(original_description)
    expect(response.body).to include(I18n.t("health_check.naming_conventions.result.reasons.confirmation_required"))
  end

  it "applies the unchanged preview as one linked admin repair operation" do
    transaction = create_naming_candidate
    expected_description = transaction.investments.first.cash_transaction_description
    sign_in admin
    token = preview_token

    expect do
      patch healthcheck_naming_convention_path,
            params: {
              apply_token: token,
              naming_confirmation: "1"
            }
    end.to change(AuditOperation.where(source: :admin_repair), :count).by(1)
                                                                      .and change(AuditVersion, :count).by(1)
                                                                                                       .and change(HealthCheckRun, :count).by(0)

    operation = AuditOperation.where(source: :admin_repair).order(:created_at).last
    expect(response).to have_http_status(:ok)
    expect(transaction.reload.description).to eq(expected_description)
    expect(operation.context_id).to eq(admin.main_context.id)
    expect(operation.actor_id).to eq(admin.id)
    expect(operation.metadata).to include(
      "maintenance_tool" => "naming_convention",
      "preview_digest" => kind_of(String)
    )
    expect(operation.audit_versions.sole).to have_attributes(
      item_type: "CashTransaction",
      item_id: transaction.id,
      mutation_source: "admin_repair"
    )
    expect(response.body).to include(audit_operation_path(operation))
  end

  it "rejects a stale preview without overwriting current data" do
    transaction = create_naming_candidate
    sign_in admin
    token = preview_token
    transaction.update_columns(description: "CHANGED AFTER PREVIEW")

    expect do
      patch healthcheck_naming_convention_path,
            params: {
              apply_token: token,
              naming_confirmation: "1"
            }
    end.to change(AuditOperation, :count).by(0).and change(AuditVersion, :count).by(0)

    expect(response).to have_http_status(:unprocessable_content)
    expect(transaction.reload.description).to eq("CHANGED AFTER PREVIEW")
    expect(response.body).to include(I18n.t("health_check.naming_conventions.result.reasons.stale_preview"))
  end

  it "does not fall back to another context when the selected context is empty" do
    transaction = create_naming_candidate
    original_description = transaction.description
    empty_context = create(:context, user: admin, name: "Empty naming scope", source_context: admin.main_context)
    sign_in admin
    patch switch_context_path(empty_context)

    get preview_healthcheck_naming_convention_path

    document = Nokogiri::HTML.fragment(response.body)
    expect(response).to have_http_status(:ok)
    expect(transaction.reload.description).to eq(original_description)
    expect(response.body).to include(I18n.t("health_check.naming_conventions.no_changes_found"))
    expect(document.at_css("form[action='#{healthcheck_naming_convention_path}']")).to be_nil
  end

  private

  def create_naming_candidate
    investment = create(
      :investment,
      :random,
      user: admin,
      context: admin.main_context,
      user_bank_account: create(:user_bank_account, :random, user: admin),
      investment_type: create(:investment_type, :random)
    )
    investment.cash_transaction.tap { |transaction| transaction.update_columns(description: "OUTDATED NAMING") }
  end

  def preview_token
    get preview_healthcheck_naming_convention_path
    Nokogiri::HTML.fragment(response.body).at_css("input#healthcheck_naming_convention_apply_token")["value"]
  end
end
