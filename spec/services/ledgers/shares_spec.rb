# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Ledger share lifecycle", type: :service do
  include ActiveSupport::Testing::TimeHelpers

  it "creates a context-bound share while returning the raw token only once" do
    entity = create(:entity, :random)

    result = Ledgers::Shares::Create.call(entity:, context: entity.user.main_context)

    expect(result.token.bytesize).to be >= 32
    expect(result.share).to have_attributes(entity:, context: entity.user.main_context, expires_at: nil, revoked_at: nil, access_count: 0)
    expect(result.share.token_digest).to eq(LedgerShare.digest_token(result.token))
    expect(result.share.attributes.values).not_to include(result.token)
  end

  it "generates a distinct token and digest for every share" do
    entity = create(:entity, :random)

    first = Ledgers::Shares::Create.call(entity:, context: entity.user.main_context)
    second = Ledgers::Shares::Create.call(entity:, context: entity.user.main_context)

    expect(second.token).not_to eq(first.token)
    expect(second.share.token_digest).not_to eq(first.share.token_digest)
  end

  it "resolves active shares and rejects unknown, expired, revoked, blank, and oversized tokens" do
    entity = create(:entity, :random)
    active = Ledgers::Shares::Create.call(entity:, context: entity.user.main_context)
    expired = create(:ledger_share, entity:, context: entity.user.main_context, expires_at: 1.day.from_now, token_digest: LedgerShare.digest_token("expired"))
    expired.update_column(:expires_at, 1.minute.ago)
    revoked = create(:ledger_share, entity:, context: entity.user.main_context, revoked_at: Time.current, token_digest: LedgerShare.digest_token("revoked"))

    expect(Ledgers::Shares::Resolve.call(token: active.token)).to eq(active.share)
    expect(Ledgers::Shares::Resolve.call(token: "unknown")).to be_nil
    expect(Ledgers::Shares::Resolve.call(token: "expired")).to be_nil
    expect(Ledgers::Shares::Resolve.call(token: "revoked")).to be_nil
    expect(Ledgers::Shares::Resolve.call(token: "")).to be_nil
    expect(Ledgers::Shares::Resolve.call(token: "x" * 257)).to be_nil
    expect(expired).to be_expired
    expect(revoked).to be_revoked
  end

  it "revokes idempotently and makes access unavailable immediately" do
    entity = create(:entity, :random)
    result = Ledgers::Shares::Create.call(entity:, context: entity.user.main_context)
    revoked_at = Time.current

    Ledgers::Shares::Revoke.call(share: result.share, at: revoked_at)
    Ledgers::Shares::Revoke.call(share: result.share, at: revoked_at + 1.minute)

    expect(result.share.reload.revoked_at).to be_within(1.second).of(revoked_at)
    expect(Ledgers::Shares::Resolve.call(token: result.token, at: revoked_at)).to be_nil
  end

  it "rotates atomically while preserving Entity, Context, and expiry" do
    entity = create(:entity, :random)
    expires_at = 2.days.from_now
    original = Ledgers::Shares::Create.call(entity:, context: entity.user.main_context, expires_at:)

    replacement = Ledgers::Shares::Rotate.call(share: original.share)

    expect(original.share.reload).to be_revoked
    expect(Ledgers::Shares::Resolve.call(token: original.token)).to be_nil
    expect(Ledgers::Shares::Resolve.call(token: replacement.token)).to eq(replacement.share)
    expect(replacement.share).to have_attributes(entity:, context: entity.user.main_context, expires_at: be_within(1.second).of(expires_at))
  end

  it "records successful access at a bounded cadence without auditing finance data" do
    entity = create(:entity, :random)
    share = Ledgers::Shares::Create.call(entity:, context: entity.user.main_context).share
    audit_operation_count = AuditOperation.count

    travel_to Time.zone.local(2026, 9, 12, 10) do
      expect(Ledgers::Shares::RecordAccess.call(share:)).to be(true)
      expect(share.reload).to have_attributes(access_count: 1, last_accessed_at: Time.current)
      expect(Ledgers::Shares::RecordAccess.call(share:, at: 1.minute.from_now)).to be(false)
      expect(share.reload.access_count).to eq(1)
      expect(Ledgers::Shares::RecordAccess.call(share:, at: 5.minutes.from_now)).to be(true)
      expect(share.reload.access_count).to eq(2)
      expect(AuditOperation.count).to eq(audit_operation_count)
    end
  end

  it "keeps authorization independent when access telemetry cannot be written" do
    share = create(:ledger_share)
    allow(LedgerShare).to receive(:available_at).and_raise(ActiveRecord::ConnectionNotEstablished)
    allow(Rails.logger).to receive(:warn)

    expect(Ledgers::Shares::RecordAccess.call(share:)).to be(false)
    expect(Rails.logger).to have_received(:warn).with("External ledger access telemetry unavailable (ActiveRecord::ConnectionNotEstablished)")
  end

  it "rolls back lifecycle mutations when their audit record cannot be persisted" do
    entity = create(:entity, :random)
    original = Ledgers::Shares::Create.call(entity:, context: entity.user.main_context).share
    allow(Ledgers::Shares::LifecycleAudit).to receive(:record!).and_raise(ActiveRecord::RecordInvalid)

    share_count = LedgerShare.count
    expect do
      Ledgers::Shares::Create.call(entity:, context: entity.user.main_context, audit: true)
    end.to raise_error(ActiveRecord::RecordInvalid)
    expect(LedgerShare.count).to eq(share_count)

    expect do
      Ledgers::Shares::Revoke.call(share: original, audit: true)
    end.to raise_error(ActiveRecord::RecordInvalid)
    expect(original.reload).not_to be_revoked

    expect do
      Ledgers::Shares::Rotate.call(share: original, audit: true)
    end.to raise_error(ActiveRecord::RecordInvalid)
    expect(LedgerShare.count).to eq(share_count)
    expect(original.reload).not_to be_revoked
  end
end
