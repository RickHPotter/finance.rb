# frozen_string_literal: true

module IndexState
  class Base
    attr_reader :current_user, :current_context, :params

    def initialize(current_user:, current_context:, params:)
      @current_user = current_user
      @current_context = current_context
      @params = params
    end

    private

    def compact_array(value)
      Array(value).flatten.compact_blank
    end

    def compact_array_to_strings(value)
      compact_array(value).map(&:to_s)
    end

    def compact_array_to_integers(value)
      compact_array(value).map(&:to_i)
    end

    def values_from(source, *keys)
      keys.index_with { |key| source[key] }
    end

    def parse_active_month_years(value)
      return [] if value.blank?

      parsed =
        case value
        when String
          JSON.parse(value)
        else
          value
        end

      compact_array_to_integers(parsed)
    rescue JSON::ParserError
      []
    end

    def boolean(value)
      ActiveModel::Type::Boolean.new.cast(value)
    end

    def subscriptions
      current_context.subscriptions.order(:description).to_a
    end

    def month_year_value(year, month)
      Date.new(year, month, 1).strftime("%Y%m").to_i
    end
  end
end
