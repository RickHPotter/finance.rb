# frozen_string_literal: true

class Audit::Rollback::State
  class << self
    def normalize(record_type, attributes)
      return nil if attributes.nil?

      model = record_type.safe_constantize
      attributes.to_h.stringify_keys.sort.to_h.each_with_object({}) do |(attribute, value), result|
        result[attribute] = normalize_value(model&.type_for_attribute(attribute), value)
      end
    end

    def canonical_json(value)
      JSON.generate(sort_recursively(value))
    end

    private

    def normalize_value(type, value)
      return nil if value.nil?

      cast_value = type&.cast(value)
      case type&.type
      when :datetime then cast_value&.utc&.iso8601(6)
      when :date then cast_value&.iso8601
      when :boolean then ActiveModel::Type::Boolean.new.cast(value)
      when :integer then cast_value.to_i
      when :decimal then cast_value.to_s
      else normalize_scalar(value)
      end
    rescue ArgumentError, TypeError
      normalize_scalar(value)
    end

    def normalize_scalar(value)
      case value
      when Time, DateTime, ActiveSupport::TimeWithZone then value.utc.iso8601(6)
      when Date then value.iso8601
      else value
      end
    end

    def sort_recursively(value)
      case value
      when Hash
        value.to_h.stringify_keys.sort.to_h.transform_values { |nested| sort_recursively(nested) }
      when Array
        value.map { |nested| sort_recursively(nested) }
      else value
      end
    end
  end
end
