# frozen_string_literal: true

HealthCheck::Repairs::Change = Data.define(:record_type, :record_id, :attribute, :before, :after, :metadata) do
  def initialize(**attributes)
    attributes.assert_valid_keys(:record_type, :record_id, :attribute, :before, :after, :metadata)
    record_type = attributes.fetch(:record_type)
    record_id = attributes.fetch(:record_id)
    attribute = attributes.fetch(:attribute)
    before = attributes.fetch(:before)
    after = attributes.fetch(:after)
    metadata = attributes.fetch(:metadata, {})

    raise ArgumentError, "record_type is required" if record_type.blank?
    raise ArgumentError, "record_id is required" if record_id.blank?
    raise ArgumentError, "attribute is required" if attribute.blank?
    raise ArgumentError, "change has no difference" if before == after

    super(
      record_type: record_type.to_s,
      record_id: record_id.to_s,
      attribute: attribute.to_s,
      before: HealthCheck::Repairs::Payload.normalize(before),
      after: HealthCheck::Repairs::Payload.normalize(after),
      metadata: HealthCheck::Repairs::Payload.normalize(metadata)
    )
  end

  def to_h
    HealthCheck::Repairs::Payload.normalize({
                                              record_type:,
                                              record_id:,
                                              attribute:,
                                              before:,
                                              after:,
                                              metadata:
                                            })
  end
end
