# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Audit history", type: :request do
  let(:user) { create(:user, :random) }
  let(:other_user) { create(:user, :random) }
  let(:admin) { create(:user, :random, admin: true) }
  let(:operation) do
    AuditOperation.create!(
      source: :web,
      result: :committed,
      actor_id: other_user.id,
      context_id: other_user.main_context.id,
      request_id: "mixed-owner-request",
      metadata: { "private_batch" => "admin-only" }
    )
  end

  def create_version(owner:, item_id:, description:, event: :update)
    AuditVersion.create!(
      operation:,
      owner_id: owner.id,
      context_id: owner.main_context.id,
      item_type: "CashTransaction",
      item_subtype: "CashTransaction",
      item_id:,
      event:,
      mutation_source: :web,
      object: { "id" => item_id, "description" => "Before #{description}" },
      object_changes: { "description" => [ "Before #{description}", description ] },
      metadata: { "user_bank_account_id" => item_id }
    )
  end

  it "requires authentication" do
    get audit_operations_path

    expect(response).to redirect_to(new_user_session_path)
  end

  it "shows an ordinary user only their side of a mixed-owner operation" do
    own_version = create_version(owner: user, item_id: 101, description: "Visible correction")
    create_version(owner: other_user, item_id: 202, description: "Foreign secret")
    sign_in user

    get audit_operation_path(operation)

    expect(response).to have_http_status(:success)
    expect(response.body).to include("Visible correction")
    expect(response.body).to include(record_audit_versions_path(item_type: "CashTransaction", item_id: own_version.item_id))
    expect(response.body).not_to include("Foreign secret", "admin-only", "mixed-owner-request")
    expect(summary_value(I18n.t("audit.fields.visible_versions"))).to eq("1")
  end

  it "scopes an ordinary user's operation index before rendering summaries" do
    create_version(owner: user, item_id: 101, description: "Owned operation")
    own_operation = operation
    foreign_operation = AuditOperation.create!(source: :web, result: :committed)
    AuditVersion.create!(
      operation: foreign_operation,
      owner_id: other_user.id,
      item_type: "CashTransaction",
      item_subtype: "CashTransaction",
      item_id: 202,
      event: :update,
      mutation_source: :web,
      object_changes: { "description" => [ "Before", "Foreign operation" ] },
      metadata: {}
    )
    sign_in user

    get audit_operations_path

    expect(response).to have_http_status(:success)
    expect(response.body).to include(own_operation.id)
    expect(response.body).not_to include(foreign_operation.id)
  end

  it "returns not found when an ordinary user cannot see any version in the operation" do
    create_version(owner: other_user, item_id: 202, description: "Foreign only")
    sign_in user

    get audit_operation_path(operation)

    expect(response).to have_http_status(:not_found)
  end

  it "allows an administrator to inspect every owner and operation metadata" do
    create_version(owner: user, item_id: 101, description: "Visible correction")
    create_version(owner: other_user, item_id: 202, description: "Foreign secret")
    sign_in admin

    get audit_operation_path(operation)

    expect(response).to have_http_status(:success)
    expect(response.body).to include("Visible correction", "Foreign secret", "admin-only", "mixed-owner-request")
    expect(summary_value(I18n.t("audit.fields.visible_versions"))).to eq("2")
  end

  it "filters the authorized version ledger without leaking another owner's match" do
    own_version = create_version(owner: user, item_id: 101, description: "Matching own version")
    create_version(owner: other_user, item_id: 101, description: "Matching foreign version")
    sign_in user

    get audit_versions_path, params: { item_type: "CashTransaction", item_id: own_version.item_id }

    expect(response).to have_http_status(:success)
    expect(response.body).to include("Matching own version")
    expect(response.body).not_to include("Matching foreign version")
  end

  it "keeps a destroyed record timeline available from immutable versions" do
    version = create_version(owner: user, item_id: 404, description: "Destroyed transaction", event: :destroy)
    sign_in user

    get record_audit_versions_path(item_type: "CashTransaction", item_id: version.item_id)

    expect(response).to have_http_status(:success)
    expect(response.body).to include("Destroyed transaction", I18n.t("audit.events.destroy"))
  end

  it "rejects unsupported record timeline types" do
    sign_in user

    get record_audit_versions_path(item_type: "User", item_id: 1)

    expect(response).to have_http_status(:not_found)
  end

  it "links supported financial show pages to their record timeline" do
    account = create(:user_bank_account, :random, user:)
    sign_in user

    get user_bank_account_path(account)

    expect(response).to have_http_status(:success)
    expect(response.body).to include(record_audit_versions_path(item_type: "UserBankAccount", item_id: account.id))
  end

  def summary_value(label)
    document = Nokogiri::HTML(response.body)
    document.xpath("//p[normalize-space()=#{label.to_json}]/following-sibling::p[1]").text.strip
  end
end
