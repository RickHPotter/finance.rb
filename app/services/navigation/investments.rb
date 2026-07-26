# frozen_string_literal: true

module Navigation
  class Investments
    QUERY_SCHEMA = {
      active_month_years: :scalar_or_array,
      default_year: :scalar,
      search_term: :scalar,
      investment: {
        id: :scalar_or_array,
        investment_type_id: :scalar_or_array,
        user_bank_account_id: :scalar_or_array
      }
    }.freeze

    attr_reader :state

    delegate :accepted?, :destination, :rejected_reason, :result, to: :state

    def initialize(raw:, fallback:, current_user:, current_context:)
      @state = State.new(
        raw:,
        fallback:,
        allowed_paths: [ Rails.application.routes.url_helpers.investments_path ],
        query_schema: QUERY_SCHEMA,
        id_scopes: {
          "investment.id" => current_context.investments,
          "investment.investment_type_id" => InvestmentType.all,
          "investment.user_bank_account_id" => current_user.user_bank_accounts
        }
      )
    end
  end
end
