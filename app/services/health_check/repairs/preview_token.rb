# frozen_string_literal: true

class HealthCheck::Repairs::PreviewToken
  PURPOSE = "health_check_repair_preview"
  EXPIRES_IN = 15.minutes

  class << self
    def generate(payload)
      verifier.generate(
        HealthCheck::Repairs::Payload.normalize(payload),
        expires_in: EXPIRES_IN,
        purpose: PURPOSE
      )
    end

    def verify(token)
      verifier.verified(token, purpose: PURPOSE)
    end

    private

    def verifier
      Rails.application.message_verifier(:health_check_repair_preview)
    end
  end
end
