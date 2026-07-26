# frozen_string_literal: true

module Navigation
  class Budgets
    QUERY_SCHEMA = {
      active_month_years: :scalar_or_array,
      default_year: :scalar,
      direction: :scalar,
      search_term: :scalar,
      sort: :scalar,
      budget: {
        id: :scalar_or_array,
        category_id: :scalar_or_array,
        entity_id: :scalar_or_array
      }
    }.freeze

    attr_reader :state

    delegate :accepted?, :destination, :rejected_reason, :result, to: :state

    def initialize(raw:, fallback:, current_user:, current_context:)
      @state = State.new(
        raw:,
        fallback:,
        allowed_paths: [ Rails.application.routes.url_helpers.budgets_path ],
        query_schema: QUERY_SCHEMA,
        id_scopes: {
          "budget.id" => current_context.budgets,
          "budget.category_id" => current_user.categories,
          "budget.entity_id" => current_user.entities
        }
      )
    end
  end
end
