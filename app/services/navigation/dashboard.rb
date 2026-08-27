# frozen_string_literal: true

require "uri"

module Navigation
  class Dashboard
    ROUTE_PATTERN = %r{\A/(cash_transactions|card_transactions|budgets|user_bank_accounts|user_cards|categories|entities|investments|subscriptions)/(\d+)\z}

    attr_reader :raw, :current_user, :current_context

    def initialize(raw:, current_user:, current_context:)
      @raw = raw
      @current_user = current_user
      @current_context = current_context
    end

    def destination
      return if raw.blank? || raw.to_s.bytesize > State::MAX_RAW_BYTES

      uri = URI.parse(raw.to_s)
      return unless uri.query.blank? && uri.fragment.blank?

      match = ROUTE_PATTERN.match(uri.path)
      return if match.blank? || !owned?(match[1], match[2])

      state = State.new(raw:, fallback: "/", allowed_paths: [ uri.path ])
      state.destination if state.accepted?
    rescue URI::InvalidURIError
      nil
    end

    private

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
  end
end
