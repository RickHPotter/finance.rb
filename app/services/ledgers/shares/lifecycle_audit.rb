# frozen_string_literal: true

class Ledgers::Shares::LifecycleAudit
  def self.record!(action:, share:, metadata: {})
    audit_metadata = ::Audit::Current.metadata.to_h.merge(
      "ledger_share_action" => action.to_s,
      "ledger_share_public_id" => share.public_id,
      "entity_public_id" => share.entity.public_id,
      **metadata.stringify_keys
    )

    ::Audit::Current.set(metadata: audit_metadata) { ::Audit::Operation.ensure_persisted! }
  end
end
