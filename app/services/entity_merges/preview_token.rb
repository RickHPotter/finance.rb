# frozen_string_literal: true

# Signs and verifies temporary 15-minute tokens for entity merges.
class EntityMerges::PreviewToken
  PURPOSE = :entity_merge_preview
  EXPIRY = 15.minutes

  class << self
    # @param plan [EntityMerges::Plan]
    # @return [String]
    def generate(plan)
      payload = {
        "actor_id" => plan.actor.id,
        "source_id" => plan.source.id,
        "destination_id" => plan.destination.id,
        "mode" => plan.mode.to_s,
        "digest" => plan.digest
      }
      Rails.application.message_verifier(PURPOSE).generate(payload, expires_in: EXPIRY)
    end

    # @param token [String]
    # @return [Hash, nil]
    def verify(token)
      Rails.application.message_verifier(PURPOSE).verify(token)
    rescue ActiveSupport::MessageVerifier::InvalidSignature, ActiveSupport::MessageVerifier::InvalidMessage
      nil
    end
  end
end
