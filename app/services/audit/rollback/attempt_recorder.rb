# frozen_string_literal: true

class Audit::Rollback::AttemptRecorder
  REASON_CODES = %w[authorization_denied operation_not_found].freeze

  class << self
    def record!(actor:, context:, request_id:, reason_code:, operation: nil)
      raise ArgumentError, "unsupported rollback rejection reason" unless reason_code.to_s.in?(REASON_CODES)

      AuditOperation.create!(
        source: :rollback,
        result: :rejected,
        actor_id: actor&.id,
        context_id: context&.id,
        request_id: request_id.presence,
        rollback_of_operation_id: operation&.id,
        metadata: { "reason_code" => reason_code.to_s }
      )
    end
  end
end
