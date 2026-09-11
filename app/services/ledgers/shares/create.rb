# frozen_string_literal: true

class Ledgers::Shares::Create
  Result = Data.define(:share, :token)

  TOKEN_BYTES = 32

  def self.call(entity:, context:, expires_at: nil)
    token = SecureRandom.urlsafe_base64(TOKEN_BYTES)
    share = LedgerShare.create!(
      entity:,
      context:,
      expires_at:,
      token_digest: LedgerShare.digest_token(token)
    )

    Result.new(share:, token:)
  end
end
