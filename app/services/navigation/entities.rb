# frozen_string_literal: true

module Navigation
  class Entities
    QUERY_SCHEMA = {
      search_term: :scalar,
      entity: {
        id: :scalar_or_array,
        status: :scalar_or_array
      }
    }.freeze

    attr_reader :state

    delegate :accepted?, :destination, :rejected_reason, :result, to: :state

    def initialize(raw:, fallback:, current_user:)
      @state = State.new(
        raw:,
        fallback:,
        allowed_paths: [ Rails.application.routes.url_helpers.entities_path ],
        query_schema: QUERY_SCHEMA,
        id_scopes: { "entity.id" => current_user.entities }
      )
    end
  end
end
