# frozen_string_literal: true

module Ledgers::ExternalSecurity
  extend ActiveSupport::Concern

  included do
    prepend_before_action :secure_external_request!
  end

  private

  def secure_external_request!
    apply_external_privacy_headers
    return if Ledgers::ExternalRateLimiter.allowed?(request:, token: external_rate_limit_identity)

    response.set_header("Retry-After", Ledgers::ExternalRateLimiter::WINDOW.to_i.to_s)
    @ledger_unavailable = true
    render Views::Ledgers::Unavailable.new, status: :too_many_requests
  end

  def apply_external_privacy_headers
    response.set_header("X-Robots-Tag", "noindex, nofollow, noarchive")
    response.set_header("Cache-Control", "private, no-store")
    response.set_header("Referrer-Policy", "no-referrer")
  end

  def external_rate_limit_identity
    params[:share_token]
  end
end
