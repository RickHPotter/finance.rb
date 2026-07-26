# frozen_string_literal: true

module Navigation
  class Subscriptions
    QUERY_SCHEMA = {
      search_term: :scalar,
      subscription: {
        id: :scalar_or_array,
        category_id: :scalar_or_array,
        entity_id: :scalar_or_array,
        status: :scalar_or_array
      }
    }.freeze

    attr_reader :state

    delegate :accepted?, :destination, :rejected_reason, :result, to: :state

    def initialize(raw:, fallback:, current_user:, current_context:)
      @state = State.new(
        raw:,
        fallback:,
        allowed_paths: [ Rails.application.routes.url_helpers.subscriptions_path ],
        query_schema: QUERY_SCHEMA,
        id_scopes: {
          "subscription.id" => current_context.subscriptions,
          "subscription.category_id" => current_user.categories,
          "subscription.entity_id" => current_user.entities
        }
      )
    end
  end
end
