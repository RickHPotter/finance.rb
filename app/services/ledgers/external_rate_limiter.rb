# frozen_string_literal: true

class Ledgers::ExternalRateLimiter
  NETWORK_LIMIT = 120
  IDENTITY_LIMIT = 60
  MONTH_FRAME_NETWORK_LIMIT = 240
  MONTH_FRAME_IDENTITY_LIMIT = 180
  WINDOW = 1.minute

  def self.allowed?(request:, token:, scope: :navigation, store: Rails.cache)
    network_limit, identity_limit = limits_for(scope)
    network_identity = digest(request.remote_ip.to_s)
    network_count = store.increment("ledger-rate-limit:#{scope}:network:#{network_identity}", 1, expires_in: WINDOW)
    return false if network_count && network_count > network_limit

    lookup_identity = digest(bounded_token(token))
    identity_count = store.increment("ledger-rate-limit:#{scope}:identity:#{network_identity}:#{lookup_identity}", 1, expires_in: WINDOW)
    identity_count.nil? || identity_count <= identity_limit
  rescue StandardError => e
    Rails.logger.warn("External ledger rate limit unavailable (#{e.class})")
    true
  end

  def self.bounded_token(token)
    value = token.to_s
    "#{value.bytesize}:#{value.byteslice(0, Ledgers::Shares::Resolve::MAX_TOKEN_BYTES)}"
  end
  private_class_method :bounded_token

  def self.limits_for(scope)
    return [ MONTH_FRAME_NETWORK_LIMIT, MONTH_FRAME_IDENTITY_LIMIT ] if scope == :month_frame

    [ NETWORK_LIMIT, IDENTITY_LIMIT ]
  end
  private_class_method :limits_for

  def self.digest(value)
    Digest::SHA256.hexdigest(value)
  end
  private_class_method :digest
end
