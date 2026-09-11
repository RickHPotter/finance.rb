# frozen_string_literal: true

class Ledgers::Shares::Revoke
  def self.call(share:, at: Time.current)
    share.with_lock do
      share.update!(revoked_at: at) if share.revoked_at.nil?
    end

    share
  end
end
