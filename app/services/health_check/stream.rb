# frozen_string_literal: true

class HealthCheck::Stream
  class << self
    def for(scope)
      name(
        user_id: scope.user.id,
        context_id: scope.context.id,
        connected_user_id: scope.connected_user&.id
      )
    end

    def name(user_id:, context_id:, connected_user_id:)
      [
        "health_check",
        "user",
        Integer(user_id),
        "context",
        Integer(context_id),
        "connected",
        connected_user_id.present? ? Integer(connected_user_id) : "all"
      ].join(":")
    end
  end
end
