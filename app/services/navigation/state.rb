# frozen_string_literal: true

require "uri"

module Navigation
  class State
    MAX_RAW_BYTES = 4.kilobytes
    MAX_VALUE_BYTES = 256
    MAX_VALUES = 50
    QUERY_TYPES = %i[array scalar scalar_or_array].freeze

    Result = Data.define(:destination, :accepted, :reason)

    attr_reader :raw, :fallback, :allowed_paths, :query_schema, :id_scopes

    def initialize(raw:, fallback:, allowed_paths:, query_schema: {}, id_scopes: {})
      @raw = raw
      @fallback = trusted_local_path!(fallback)
      @allowed_paths = allowed_paths.map { |path| trusted_local_path!(path, path_only: true) }.uniq.freeze
      @query_schema = normalize_schema(query_schema).freeze
      @id_scopes = id_scopes.transform_keys(&:to_s).freeze
    end

    def destination
      result.destination
    end

    def accepted?
      result.accepted
    end

    def rejected_reason
      result.reason unless accepted?
    end

    def result
      @result ||= resolve
    end

    private

    def resolve
      return rejected(:missing) if raw.blank?

      raw_value = raw.to_s
      return rejected(:too_long) if raw_value.bytesize > MAX_RAW_BYTES
      return rejected(:unsafe_url) if unsafe_raw_value?(raw_value)

      uri = URI.parse(raw_value)
      return rejected(:unsafe_url) unless safe_local_uri?(uri, raw_value)
      return rejected(:path_not_allowed) unless allowed_paths.include?(uri.path)

      query = sanitize_query(uri.query)
      return rejected(:foreign_identifier) unless identifiers_owned?(query)

      Result.new(destination: destination_for(uri.path, query), accepted: true, reason: nil)
    rescue URI::InvalidURIError
      rejected(:malformed_uri)
    rescue Rack::QueryParser::ParameterTypeError, Rack::QueryParser::InvalidParameterError
      rejected(:malformed_query)
    rescue InvalidQueryShape
      rejected(:invalid_query_shape)
    end

    def trusted_local_path!(value, path_only: false)
      raw_value = value.to_s
      uri = URI.parse(raw_value)
      raise ArgumentError, "fallback and allowed paths must be local absolute paths" unless safe_local_uri?(uri, raw_value)
      raise ArgumentError, "allowed paths cannot include query state" if path_only && uri.query.present?

      path_only ? uri.path : raw_value
    rescue URI::InvalidURIError
      raise ArgumentError, "fallback and allowed paths must be valid URIs"
    end

    def safe_local_uri?(uri, raw_value)
      raw_value.start_with?("/") &&
        !raw_value.start_with?("//") &&
        !raw_value.include?("\\") &&
        uri.scheme.nil? &&
        uri.host.nil? &&
        uri.userinfo.nil? &&
        uri.fragment.nil?
    end

    def unsafe_raw_value?(raw_value)
      raw_value.match?(/[[:cntrl:]]/)
    end

    def sanitize_query(raw_query)
      return {} if raw_query.blank?

      @value_count = 0
      parsed = Rack::Utils.parse_nested_query(raw_query)
      sanitize_hash(parsed, query_schema)
    end

    def sanitize_hash(source, schema)
      raise InvalidQueryShape unless source.is_a?(Hash)

      schema.each_with_object({}) do |(key, rule), sanitized|
        next unless source.key?(key)

        value = sanitize_value(source[key], rule)
        sanitized[key] = value if value.present?
      end
    end

    def sanitize_value(value, rule)
      return sanitize_hash(value, rule) if rule.is_a?(Hash)

      case rule
      when :scalar
        sanitize_scalar(value)
      when :array
        sanitize_array(value)
      when :scalar_or_array
        value.is_a?(Array) ? sanitize_array(value) : sanitize_scalar(value)
      else
        raise ArgumentError, "unsupported navigation query rule: #{rule.inspect}"
      end
    end

    def sanitize_scalar(value)
      raise InvalidQueryShape if value.is_a?(Array) || value.is_a?(Hash)

      string = value.to_s
      raise InvalidQueryShape if string.bytesize > MAX_VALUE_BYTES || string.match?(/[[:cntrl:]]/)

      increment_value_count!
      string.presence
    end

    def sanitize_array(value)
      raise InvalidQueryShape unless value.is_a?(Array)
      raise InvalidQueryShape if value.size > MAX_VALUES

      value.filter_map { |item| sanitize_scalar(item) }
    end

    def increment_value_count!
      @value_count += 1
      raise InvalidQueryShape if @value_count > MAX_VALUES
    end

    def identifiers_owned?(query)
      id_scopes.all? do |key_path, scope|
        values = query.dig(*key_path.split("."))
        next true if values.blank?

        identifiers = Array(values).map(&:to_s)
        next false unless identifiers.all? { |identifier| identifier.match?(/\A[1-9]\d*\z/) }

        identifiers_owned_by_scope?(identifiers.uniq, scope)
      end
    end

    def identifiers_owned_by_scope?(identifiers, scope)
      return scope.call(identifiers) if scope.respond_to?(:call)

      scope.where(id: identifiers).distinct.ids.map(&:to_s).sort == identifiers.sort
    end

    def destination_for(path, query)
      return path if query.empty?

      "#{path}?#{query.to_query}"
    end

    def normalize_schema(schema)
      schema.to_h.each_with_object({}) do |(key, rule), normalized|
        normalized[key.to_s] =
          if rule.respond_to?(:to_h) && !QUERY_TYPES.include?(rule)
            normalize_schema(rule.to_h)
          else
            rule.to_sym
          end
      end
    end

    def rejected(reason)
      Result.new(destination: fallback, accepted: false, reason:)
    end

    class InvalidQueryShape < StandardError; end
    private_constant :InvalidQueryShape
  end
end
