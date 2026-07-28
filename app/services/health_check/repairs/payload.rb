# frozen_string_literal: true

module HealthCheck::Repairs::Payload
  module_function

  def normalize(value)
    normalized = case value
                 when ActiveRecord::Base
                   raise ArgumentError, "financial records are not valid repair payload values"
                 when Hash
                   value.to_h.stringify_keys.sort.to_h.transform_values { |nested| normalize(nested) }
                 when Array
                   value.map { |nested| normalize(nested) }
                 when Time, DateTime, ActiveSupport::TimeWithZone
                   value.utc.iso8601(6)
                 when Date
                   value.iso8601
                 when BigDecimal
                   value.to_s("F")
                 when Symbol
                   value.to_s
                 else
                   value
                 end

    deep_freeze(normalized)
  end

  def canonical_json(value)
    JSON.generate(normalize(value))
  end

  def deep_freeze(value)
    case value
    when Hash
      value.each do |key, nested|
        deep_freeze(key)
        deep_freeze(nested)
      end
    when Array
      value.each { |nested| deep_freeze(nested) }
    end

    value.freeze
  end
end
