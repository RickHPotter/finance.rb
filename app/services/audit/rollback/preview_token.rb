# frozen_string_literal: true

class Audit::Rollback::PreviewToken
  PURPOSE = "audit_rollback_preview"

  class << self
    def generate(operation_id:, digest:, actor_id:)
      verifier.generate(
        { "operation_id" => operation_id, "digest" => digest, "actor_id" => actor_id },
        purpose: PURPOSE
      )
    end

    def verify(token)
      verifier.verified(token, purpose: PURPOSE)
    end

    private

    def verifier
      Rails.application.message_verifier(:audit_rollback_preview)
    end
  end
end
