# frozen_string_literal: true

# Backend Module to abstract
module Backend
  # Helper Module for models that are nested
  module NestedHelper
    # Check if the attributes are an array of hashes of valid models.
    #
    # @param model [String] The name of the model.
    # @param attributes [Array<Hash>] The attributes to check.
    # @param block [Proc] The block to call with each attribute.
    #
    # @ return [Boolean]
    #
    def check_array_of_hashes_of(attributes_hash = [{}], &block)
      key = attributes_hash.keys.first
      attributes = attributes_hash.values.first

      errors.add(key, "should be an array of hashes of valid #{key}")
      return false unless attributes.is_a?(Array)

      attributes.each do |attribute|
        next if attribute.is_a?(Hash) && block.call(attribute)

        return false
      end

      errors.delete(key)
      true
    end
  end
end
