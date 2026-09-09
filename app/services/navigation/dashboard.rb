# frozen_string_literal: true

require "uri"

module Navigation
  class Dashboard
    ROUTE_PATTERN = %r{\A/(cash_transactions|card_transactions|budgets|user_bank_accounts|user_cards|categories|entities|investments|subscriptions)/(\d+)\z}
    REPORTABLE_RESOURCES = %w[budgets user_bank_accounts user_cards categories entities].freeze
    REPORT_QUERY_SCHEMA = {
      from_date: :scalar,
      to_date: :scalar,
      granularity: :scalar,
      paid_state: :scalar,
      direction: :scalar,
      sort: :scalar
    }.freeze

    attr_reader :raw, :current_user, :current_context

    def initialize(raw:, current_user:, current_context:)
      @raw = raw
      @current_user = current_user
      @current_context = current_context
    end

    def destination
      return if raw.blank? || raw.to_s.bytesize > State::MAX_RAW_BYTES

      uri = URI.parse(raw.to_s)
      return unless uri.fragment.blank?

      resource, id = route_identity(uri.path)
      return if resource.blank? || !owned?(resource, id)
      return if uri.query.present? && !resource.in?(REPORTABLE_RESOURCES)

      state = navigation_state(uri)
      return unless state.accepted?

      validate_report_query!(state.destination) if uri.query.present?
      state.destination
    rescue URI::InvalidURIError, Reports::QueryState::InvalidState
      nil
    end

    private

    def route_identity(path)
      match = ROUTE_PATTERN.match(path)
      [ match&.[](1), match&.[](2) ]
    end

    def navigation_state(uri)
      State.new(
        raw:,
        fallback: "/",
        allowed_paths: [ uri.path ],
        query_schema: uri.query.present? ? REPORT_QUERY_SCHEMA : {}
      )
    end

    def owned?(resource, id)
      scope_for(resource).where(id:).exists?
    end

    def scope_for(resource)
      case resource
      when "cash_transactions" then current_context.cash_transactions
      when "card_transactions" then current_context.card_transactions
      when "budgets" then current_context.budgets
      when "user_bank_accounts" then current_user.user_bank_accounts
      when "user_cards" then current_user.user_cards
      when "categories" then current_user.categories
      when "entities" then current_user.entities
      when "investments" then current_context.investments
      when "subscriptions" then current_context.subscriptions
      else ApplicationRecord.none
      end
    end

    def validate_report_query!(destination)
      query = Rack::Utils.parse_nested_query(URI.parse(destination).query)
      Reports::QueryState.new(query)
    end
  end
end
