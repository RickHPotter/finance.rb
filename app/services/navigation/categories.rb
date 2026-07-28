# frozen_string_literal: true

module Navigation
  class Categories
    QUERY_SCHEMA = {
      search_term: :scalar,
      category: {
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
        allowed_paths: [ Rails.application.routes.url_helpers.categories_path ],
        query_schema: QUERY_SCHEMA,
        id_scopes: { "category.id" => current_user.categories }
      )
    end
  end
end
