# frozen_string_literal: true

AllocationMutations::Action = Data.define(:allocation_type, :operation, :source_id, :destination_id) do
  def initialize(allocation_type:, operation:, source_id: nil, destination_id: nil)
    allocation_type = allocation_type.to_s.to_sym
    operation = operation.to_s.to_sym
    source_id = normalize_id(source_id)
    destination_id = normalize_id(destination_id)

    raise ArgumentError, "unsupported allocation type: #{allocation_type}" unless allocation_type.in?(self.class::ALLOCATION_TYPES)
    raise ArgumentError, "unsupported allocation operation: #{operation}" unless operation.in?(self.class::OPERATIONS)

    validate_identifiers!(operation:, source_id:, destination_id:)

    super
  end

  def add?
    operation == :add
  end

  def remove?
    operation == :remove
  end

  def switch?
    operation == :switch
  end

  private

  def normalize_id(value)
    return if value.blank?

    Integer(value, exception: false).tap do |id|
      raise ArgumentError, "allocation identifiers must be positive integers" unless id&.positive?
    end
  end

  def validate_identifiers!(operation:, source_id:, destination_id:)
    case operation
    when :add
      raise ArgumentError, "add requires only a destination" if source_id.present? || destination_id.blank?
    when :remove
      raise ArgumentError, "remove requires only a source" if source_id.blank? || destination_id.present?
    when :switch
      raise ArgumentError, "switch requires a source and destination" if source_id.blank? || destination_id.blank?
    end
  end
end

AllocationMutations::Action::ALLOCATION_TYPES = %i[category entity].freeze
AllocationMutations::Action::OPERATIONS = %i[add remove switch].freeze
