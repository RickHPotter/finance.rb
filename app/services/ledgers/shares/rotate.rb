# frozen_string_literal: true

class Ledgers::Shares::Rotate
  class UnavailableError < StandardError; end

  def self.call(share:, expires_at: share.expires_at, at: Time.current, audit: false)
    LedgerShare.transaction do
      share.lock!
      raise UnavailableError, "Cannot rotate an unavailable ledger share" unless share.available_at?(at)

      result = Ledgers::Shares::Create.call(entity: share.entity, context: share.context, expires_at:)
      share.update!(revoked_at: at)
      if audit
        Ledgers::Shares::LifecycleAudit.record!(
          action: :rotate,
          share: result.share,
          metadata: { previous_share_public_id: share.public_id }
        )
      end
      result
    end
  end
end
