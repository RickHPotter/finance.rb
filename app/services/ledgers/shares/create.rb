# frozen_string_literal: true

class Ledgers::Shares::Create
  Result = Data.define(:share, :token)

  TOKEN_BYTES = 32

  def self.call(entity:, context:, expires_at: nil, audit: false)
    LedgerShare.transaction do
      token = SecureRandom.urlsafe_base64(TOKEN_BYTES)
      share = LedgerShare.create!(
        entity:,
        context:,
        expires_at:,
        token_digest: LedgerShare.digest_token(token)
      )
      Ledgers::Shares::LifecycleAudit.record!(action: :create, share:) if audit

      Result.new(share:, token:)
    end
  end
end
