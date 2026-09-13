# frozen_string_literal: true

class Ledgers::Shares::Resolve
  MAX_TOKEN_BYTES = 256

  def self.call(token:, at: Time.current)
    return if token.blank? || token.bytesize > MAX_TOKEN_BYTES

    LedgerShare.available_at(at)
               .includes(:entity, :context)
               .find_by(token_digest: LedgerShare.digest_token(token))
  end
end
