# frozen_string_literal: true

module Ledgers::ExternalSecurity
  extend ActiveSupport::Concern

  included do
    prepend_before_action :secure_external_request!
  end

  private

  def secure_external_request!
    apply_external_privacy_headers
    return if Ledgers::ExternalRateLimiter.allowed?(request:, token: external_rate_limit_identity, scope: external_rate_limit_scope)

    response.set_header("Retry-After", Ledgers::ExternalRateLimiter::WINDOW.to_i.to_s)
    @ledger_unavailable = true
    render Views::Ledgers::RateLimited.new(frame_id: external_rate_limit_frame_id), status: :too_many_requests
  end

  def apply_external_privacy_headers
    response.set_header("X-Robots-Tag", "noindex, nofollow, noarchive")
    response.set_header("Cache-Control", "private, no-store")
    response.set_header("Referrer-Policy", "no-referrer")
  end

  def external_rate_limit_identity
    params[:share_token]
  end

  def external_rate_limit_scope
    external_rate_limit_frame_id ? :month_frame : :navigation
  end

  def external_rate_limit_frame_id
    return unless action_name == "month_year"

    frame_id = request.headers["Turbo-Frame"].to_s
    frame_id if frame_id.match?(/\Amonth_year_container_\d{6}\z/)
  end
end
