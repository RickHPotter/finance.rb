# frozen_string_literal: true

class HealthCheck::NamingConventions::PreviewToken
  PURPOSE = "health_check_naming_convention_preview"
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
      Rails.application.message_verifier(:health_check_naming_convention_preview)
    end
  end
end
