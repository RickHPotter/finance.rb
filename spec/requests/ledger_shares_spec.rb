# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Ledger share management", type: :request do
  let(:owner) { create(:user, :random) }
  let(:entity) { create(:entity, user: owner, entity_name: "SHAREABLE ENTITY") }
  let(:context) { owner.main_context }

  before { sign_in owner }

  it "shows context-scoped lifecycle state and telemetry without recoverable bearer secrets" do
    active = Ledgers::Shares::Create.call(entity:, context:)
    active.share.update_columns(access_count: 3, last_accessed_at: Time.zone.local(2026, 9, 12, 10))
    expired = Ledgers::Shares::Create.call(entity:, context:)
    expired.share.update_column(:expires_at, 1.minute.ago)
    revoked = Ledgers::Shares::Create.call(entity:, context:)
    Ledgers::Shares::Revoke.call(share: revoked.share)

    get entity_path(entity)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Shared ledger access", "Active", "Expired", "Revoked", "3", context.name)
    expect(response.parsed_body.at_css("form[action='#{entity_ledger_shares_path(entity)}']")).to be_present
    expect(response.body).not_to include(active.token, expired.token, revoked.token)
    expect(response.body).not_to include(active.share.token_digest, expired.share.token_digest, revoked.share.token_digest)
  end

  it "creates and audits a share while returning its copyable URL only once" do
    expect do
      post entity_ledger_shares_path(entity),
           params: { ledger_share: { expires_at: 2.days.from_now.strftime("%Y-%m-%dT%H:%M") } },
           headers: turbo_stream_headers
    end.to change(LedgerShare, :count).by(1).and change(AuditOperation, :count).by(1)

    expect(response).to have_http_status(:created)
    document = Nokogiri::HTML.fragment(response.body)
    replacement = document.at_css("turbo-stream[action='replace'][target='entity_ledger_shares'] template")
    source = replacement.at_css("#created_ledger_share_url")
    expect(source).to be_present
    expect(source["value"]).to include("/shared/")
    token = source["value"].split("/").last
    share = Ledgers::Shares::Resolve.call(token:)
    operation = AuditOperation.order(:created_at).last
    expect(share).to be_present
    expect(operation.metadata).to include(
      "ledger_share_action" => "create",
      "ledger_share_public_id" => share.public_id,
      "entity_public_id" => entity.public_id
    )
    expect(operation.audit_versions).to be_empty

    get entity_path(entity)

    expect(response.body).not_to include(token, "created_ledger_share_url")
  end

  it "revokes only the selected share without touching financial data or another grant" do
    target = Ledgers::Shares::Create.call(entity:, context:).share
    unrelated = Ledgers::Shares::Create.call(entity:, context:).share
    transaction = create(:cash_transaction, :random, user: owner, context:)
    financial_snapshot = transaction.attributes

    delete entity_ledger_share_path(entity, target.public_id), headers: turbo_stream_headers

    expect(response).to have_http_status(:ok)
    expect(target.reload).to be_revoked
    expect(unrelated.reload).not_to be_revoked
    expect(transaction.reload.attributes).to eq(financial_snapshot)
    expect(AuditOperation.order(:created_at).last.audit_versions).to be_empty
  end

  it "atomically replaces an active share and returns the new one-time URL" do
    original = Ledgers::Shares::Create.call(entity:, context:, expires_at: 2.days.from_now)

    patch rotate_entity_ledger_share_path(entity, original.share.public_id), headers: turbo_stream_headers

    expect(response).to have_http_status(:ok)
    expect(original.share.reload).to be_revoked
    source = Nokogiri::HTML.fragment(response.body).at_css("#created_ledger_share_url")
    replacement = Ledgers::Shares::Resolve.call(token: source["value"].split("/").last)
    expect(replacement).to have_attributes(entity:, context:, expires_at: be_within(1.second).of(original.share.expires_at))
    expect(AuditOperation.order(:created_at).last.metadata).to include(
      "ledger_share_action" => "rotate",
      "previous_share_public_id" => original.share.public_id
    )
  end

  it "rejects invalid expiry input without creating a share or audit operation" do
    share_count = LedgerShare.count
    operation_count = AuditOperation.count

    post entity_ledger_shares_path(entity),
         params: { ledger_share: { expires_at: "not-a-date" } },
         headers: turbo_stream_headers

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("Enter a valid expiry date and time.")
    expect(LedgerShare.count).to eq(share_count)
    expect(AuditOperation.count).to eq(operation_count)
  end

  it "does not let another user inspect or mutate the owner's grants" do
    owned_share = Ledgers::Shares::Create.call(entity:, context:).share
    intruder = create(:user, :random)
    sign_out owner
    sign_in intruder

    post entity_ledger_shares_path(entity), params: { ledger_share: { expires_at: "" } }
    expect(response).to have_http_status(:not_found)

    sign_in intruder
    delete entity_ledger_share_path(entity, owned_share.public_id)
    expect(response).to have_http_status(:not_found)
    expect(owned_share.reload).not_to be_revoked
  end
end
