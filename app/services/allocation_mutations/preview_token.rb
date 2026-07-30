# frozen_string_literal: true

class AllocationMutations::PreviewToken
  PURPOSE = "allocation_mutation_preview"
  EXPIRES_IN = 15.minutes

  class << self
    def generate(payload)
      verifier.generate(
        AllocationMutations::Payload.normalize(payload),
        expires_in: EXPIRES_IN,
        purpose: PURPOSE
      )
    end

    def verify(token)
      verifier.verified(token, purpose: PURPOSE)
    end

    private

    def verifier
      Rails.application.message_verifier(:allocation_mutation_preview)
    end
  end
end
