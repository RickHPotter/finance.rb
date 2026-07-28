# frozen_string_literal: true

class Audit::Operation
  class InvalidContextError < StandardError; end

  class << self
    def run(source:, join_existing: true, **options, &)
      return yield if Audit::Current.active? && join_existing

      attributes = context_attributes(source:, options:)

      Audit::Current.set(**attributes) do
        PaperTrail.request(whodunnit: attributes[:actor_id]&.to_s, &)
      end
    end

    def with_mutation_source(source, &)
      validate_mutation_source!(source)

      if Audit::Current.active?
        Audit::Current.set(mutation_source: source.to_s, &)
      else
        run(source: :unknown) do
          Audit::Current.set(mutation_source: source.to_s, &)
        end
      end
    end

    def ensure_persisted!
      return create_unknown_operation! unless Audit::Current.active?

      AuditOperation.find_by(id: Audit::Current.operation_id) || AuditOperation.create!(operation_attributes)
    end

    private

    def context_attributes(source:, options:)
      validate_root_source!(source)
      options.assert_valid_keys(:actor, :context, :request_id, :parent_operation_id, :rollback_of_operation_id, :selected_version_id, :metadata)

      {
        operation_id: SecureRandom.uuid,
        actor_id: record_id(options[:actor]),
        context_id: record_id(options[:context]),
        request_id: options[:request_id].presence,
        root_source: source.to_s,
        mutation_source: source.to_s,
        parent_operation_id: record_id(options[:parent_operation_id]),
        rollback_of_operation_id: record_id(options[:rollback_of_operation_id]),
        selected_version_id: record_id(options[:selected_version_id]),
        metadata: normalize_metadata(options.fetch(:metadata, {}))
      }
    end

    def operation_attributes
      {
        id: Audit::Current.operation_id,
        actor_id: Audit::Current.actor_id,
        context_id: Audit::Current.context_id,
        request_id: Audit::Current.request_id,
        source: Audit::Current.root_source,
        result: :committed,
        parent_operation_id: Audit::Current.parent_operation_id,
        rollback_of_operation_id: Audit::Current.rollback_of_operation_id,
        selected_version_id: Audit::Current.selected_version_id,
        metadata: Audit::Current.metadata || {}
      }
    end

    def create_unknown_operation!
      AuditOperation.create!(source: :unknown, result: :committed)
    end

    def record_id(record_or_id)
      record_or_id.respond_to?(:id) ? record_or_id.id : record_or_id
    end

    def normalize_metadata(metadata)
      raise InvalidContextError, "metadata must be a hash" unless metadata.respond_to?(:to_h)

      metadata.to_h.each_with_object({}) do |(key, value), normalized|
        raise InvalidContextError, "metadata values must be scalar" unless value.nil? || value.is_a?(String) || value.is_a?(Numeric) || value.in?([ true, false ])

        normalized[key.to_s] = value
      end
    end

    def validate_root_source!(source)
      return if source.to_s.in?(AuditOperation::ROOT_SOURCES)

      raise InvalidContextError, "unsupported audit operation source: #{source}"
    end

    def validate_mutation_source!(source)
      return if source.to_s.in?(AuditVersion::MUTATION_SOURCES)

      raise InvalidContextError, "unsupported audit mutation source: #{source}"
    end
  end
end
