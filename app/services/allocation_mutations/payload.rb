# frozen_string_literal: true

class AllocationMutations::Payload
  class << self
    def canonical_json(value)
      JSON.generate(canonicalize(value))
    end

    def normalize(value)
      case value
      when Hash
        value.each_with_object({}) { |(key, nested), normalized| normalized[key.to_s] = normalize(nested) }
      when Array
        value.map { |nested| normalize(nested) }
      when Symbol
        value.to_s
      when Date, Time, DateTime
        value.iso8601
      else
        value
      end
    end

    private

    def canonicalize(value)
      normalized = normalize(value)
      return normalized.sort.to_h.transform_values { |nested| canonicalize(nested) } if normalized.is_a?(Hash)
      return normalized.map { |nested| canonicalize(nested) } if normalized.is_a?(Array)

      normalized
    end
  end
end
