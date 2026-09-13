# frozen_string_literal: true

class Ledgers::Shares::Revoke
  def self.call(share:, at: Time.current, audit: false)
    share.with_lock do
      if share.revoked_at.nil?
        share.update!(revoked_at: at)
        Ledgers::Shares::LifecycleAudit.record!(action: :revoke, share:) if audit
      end
    end

    share
  end
end
