# frozen_string_literal: true

# Signs and verifies tamper-proof preview tokens for category merge operations.
#
# A token binds a specific actor, source category, destination category, and
# plan digest. Apply re-runs the Planner inside a transaction and refuses to
# proceed if the fresh digest differs from the token's — protecting against
# concurrent mutations that change the impact between preview and execution.
class CategoryMerges::PreviewToken
  PURPOSE    = "category_merge_preview"
  EXPIRES_IN = 15.minutes

  class << self
    # Generates a signed, time-limited token from an eligible Plan.
    #
    # @param plan [CategoryMerges::Plan] must be eligible?
    # @return [String] signed token string
    def generate(plan)
      verifier.generate(
        {
          actor_id: plan.actor.id,
          source_id: plan.source.id,
          destination_id: plan.destination.id,
          digest: plan.digest
        },
        expires_in: EXPIRES_IN,
        purpose: PURPOSE
      )
    end

    # Verifies the token and returns the payload hash, or nil if invalid/expired.
    #
    # @param token [String]
    # @return [Hash, nil]
    def verify(token)
      verifier.verified(token, purpose: PURPOSE)
    end

    private

    def verifier
      Rails.application.message_verifier(:category_merge_preview)
    end
  end
end
