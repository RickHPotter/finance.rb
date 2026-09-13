# frozen_string_literal: true

class Ledgers::Shares::RecordAccess
  WRITE_INTERVAL = 5.minutes

  def self.call(share:, at: Time.current)
    return false if share.blank?

    updated = LedgerShare.available_at(at)
                         .where(id: share.id)
                         .where("last_accessed_at IS NULL OR last_accessed_at <= ?", at - WRITE_INTERVAL)
                         .update_all([ "last_accessed_at = ?, access_count = access_count + 1, updated_at = ?", at, at ])
    updated == 1
  rescue StandardError => e
    Rails.logger.warn("External ledger access telemetry unavailable (#{e.class})")
    false
  end
end
