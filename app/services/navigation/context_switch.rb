# frozen_string_literal: true

require "uri"

module Navigation
  class ContextSwitch
    SIMPLE_DESTINATIONS = {
      "balances" => "/balances",
      "contexts" => "/contexts",
      "conversations" => "/conversations",
      "static" => "/static/donation"
    }.freeze

    RESOURCE_DESTINATIONS = {
      "budgets" => "/budgets",
      "card_transactions" => "/card_transactions",
      "cash_transactions" => "/cash_transactions",
      "categories" => "/categories",
      "entities" => "/entities",
      "investments" => "/investments",
      "references" => "/user_cards",
      "subscriptions" => "/subscriptions",
      "user_bank_accounts" => "/user_bank_accounts",
      "user_cards" => "/user_cards"
    }.freeze

    attr_reader :raw, :fallback, :current_user, :current_context, :recognized_route

    def initialize(raw:, fallback:, current_user:, current_context:)
      @raw = raw
      @fallback = fallback
      @current_user = current_user
      @current_context = current_context
      @recognized_route = recognize_safe_route
    end

    def destination
      return fallback if recognized_route.blank?
      return conversations_path if conversation_detail?
      return resource_index_fallback unless restorable_index_route?

      validated_index_destination
    end

    def redirected_conversation?
      conversation_detail?
    end

    private

    def recognize_safe_route
      raw_value = raw.to_s
      return {} if raw_value.blank? || !raw_value.start_with?("/") || raw_value.start_with?("//") || raw_value.include?("\\")

      uri = URI.parse(raw_value)
      return {} if uri.scheme.present? || uri.host.present? || uri.userinfo.present? || uri.fragment.present?

      Rails.application.routes.recognize_path(uri.path, method: :get).with_indifferent_access
    rescue URI::InvalidURIError, ActionController::RoutingError
      {}
    end

    def conversation_detail?
      recognized_route[:controller] == "conversations" && recognized_route[:action] == "show"
    end

    def restorable_index_route?
      recognized_route[:action] == "index" ||
        (recognized_route[:controller] == "card_transactions" && recognized_route[:action] == "search") ||
        (recognized_route[:controller] == "static" && recognized_route[:action] == "donation")
    end

    def validated_index_destination
      case recognized_route[:controller]
      when "cash_transactions" then cash_navigation.destination
      when "card_transactions" then card_navigation.destination
      when "budgets" then budget_navigation.destination
      when "investments" then investment_navigation.destination
      when "subscriptions" then subscription_navigation.destination
      when "categories" then category_navigation.destination
      when "entities" then entity_navigation.destination
      when "user_bank_accounts" then account_navigation.destination
      when "user_cards" then user_card_navigation.destination
      when "balances" then simple_state("/balances", tab: :scalar, month: :scalar).destination
      when "contexts" then simple_state("/contexts").destination
      when "conversations" then simple_state("/conversations").destination
      when "static" then simple_state("/static/donation").destination
      else fallback
      end
    end

    def resource_index_fallback
      RESOURCE_DESTINATIONS.fetch(recognized_route[:controller]) do
        SIMPLE_DESTINATIONS.fetch(recognized_route[:controller], fallback)
      end
    end

    def cash_navigation
      Navigation::CashTransactions.new(raw:, fallback: recognized_path, current_user:, current_context:)
    end

    def card_navigation
      Navigation::CardTransactions.new(raw:, fallback: "/card_transactions", current_user:, current_context:)
    end

    def budget_navigation
      Navigation::Budgets.new(raw:, fallback: "/budgets", current_user:, current_context:)
    end

    def investment_navigation
      Navigation::Investments.new(raw:, fallback: "/investments", current_user:, current_context:)
    end

    def subscription_navigation
      Navigation::Subscriptions.new(raw:, fallback: "/subscriptions", current_user:, current_context:)
    end

    def category_navigation
      Navigation::Categories.new(raw:, fallback: "/categories", current_user:)
    end

    def entity_navigation
      Navigation::Entities.new(raw:, fallback: "/entities", current_user:)
    end

    def account_navigation
      Navigation::UserBankAccounts.new(raw:, fallback: "/user_bank_accounts", current_user:)
    end

    def user_card_navigation
      Navigation::UserCards.new(raw:, fallback: "/user_cards", current_user:)
    end

    def simple_state(path, query_schema = {})
      Navigation::State.new(raw:, fallback: path, allowed_paths: [ path ], query_schema:)
    end

    def recognized_path
      URI.parse(raw.to_s).path
    end

    def conversations_path
      Rails.application.routes.url_helpers.conversations_path
    end
  end
end
