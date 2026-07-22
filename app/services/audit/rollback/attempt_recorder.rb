# frozen_string_literal: true

class Audit::Rollback::AttemptRecorder
  REASON_CODES = %w[
    authorization_denied operation_not_found invalid_token token_actor_mismatch
    token_operation_mismatch stale_preview preview_not_applyable confirmation_required
    validation_failed integrity_failed unexpected_failure
  ].freeze

  class << self
    def record!(actor:, context:, request_id:, reason_code:, **options)
      raise ArgumentError, "unsupported rollback rejection reason" unless reason_code.to_s.in?(REASON_CODES)

      AuditOperation.create!(
        source: :rollback,
        result: options.fetch(:result, :rejected),
        actor_id: actor&.id,
        context_id: context&.id,
        request_id: request_id.presence,
        rollback_of_operation_id: options[:operation]&.id,
        metadata: { "reason_code" => reason_code.to_s, "preview_digest" => options[:preview_digest] }.compact
      )
    end
  end
end
