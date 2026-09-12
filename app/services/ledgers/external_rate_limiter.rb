# frozen_string_literal: true

class Ledgers::ExternalRateLimiter
  NETWORK_LIMIT = 120
  IDENTITY_LIMIT = 60
  WINDOW = 1.minute

  def self.allowed?(request:, token:, store: Rails.cache)
    network_identity = digest(request.remote_ip.to_s)
    network_count = store.increment("ledger-rate-limit:network:#{network_identity}", 1, expires_in: WINDOW)
    return false if network_count && network_count > NETWORK_LIMIT

    lookup_identity = digest(bounded_token(token))
    identity_count = store.increment("ledger-rate-limit:identity:#{network_identity}:#{lookup_identity}", 1, expires_in: WINDOW)
    identity_count.nil? || identity_count <= IDENTITY_LIMIT
  rescue StandardError => e
    Rails.logger.warn("External ledger rate limit unavailable (#{e.class})")
    true
  end

  def self.bounded_token(token)
    value = token.to_s
    "#{value.bytesize}:#{value.byteslice(0, Ledgers::Shares::Resolve::MAX_TOKEN_BYTES)}"
  end
  private_class_method :bounded_token

  def self.digest(value)
    Digest::SHA256.hexdigest(value)
  end
  private_class_method :digest
end
