# frozen_string_literal: true

class Audit::BulkMutation
  class << self
    def update_columns!(record, attributes)
      unless audited_model?(record.class)
        record.update_columns(attributes)
        return record
      end

      attributes = attributes.stringify_keys
      audited, skipped = attributes.partition { |name, _| audited_attribute?(record, name) }.map(&:to_h)

      record.class.transaction do
        persisted_record = record.class.unscoped.find(record.id)
        audited = changed_attributes(persisted_record, audited)
        skipped = changed_attributes(persisted_record, skipped)

        record_audited_update!(persisted_record, audited) if audited.present?
        persisted_record.update_columns(skipped) if skipped.present?
        synchronize_attributes(record, persisted_record, audited.keys + skipped.keys)
      end

      record
    end

    def update_all!(relation, attributes)
      relation.find_each { |record| update_columns!(record, attributes) }
    end

    def delete_all!(relation)
      records = relation.to_a
      return 0 if records.empty?

      relation.model.transaction do
        records.each { |record| record.paper_trail.record_destroy("before") }
        deleted_count = relation.where(relation.model.primary_key => records.map(&:id)).delete_all
        relation.reset
        deleted_count
      end
    end

    def insert!(model, attributes)
      raise ArgumentError, "#{model.name} is not financially audited" unless audited_model?(model)

      model.transaction do
        result = model.insert!(attributes)
        record = model.find(result.rows.first.first)
        record_insert_version!(record)
        record
      end
    end

    def audited_model?(model)
      model.respond_to?(:paper_trail_options) && model.paper_trail_options.present?
    end

    private

    def audited_attribute?(record, name)
      record.class.paper_trail_options.fetch(:skip).exclude?(name.to_s)
    end

    def changed_attributes(record, attributes)
      attributes.reject do |name, value|
        record[name] == record.class.type_for_attribute(name).cast(value)
      end
    end

    def synchronize_attributes(record, persisted_record, attribute_names)
      attribute_names.each do |name|
        record[name] = persisted_record[name]
        record.send(:clear_attribute_change, name)
      end
    end

    def record_audited_update!(record, attributes)
      record.assign_attributes(attributes)
      record.paper_trail.record_update(force: true, in_after_callback: false, is_touch: false)
      record.update_columns(attributes)
    end

    def record_insert_version!(record)
      ownership = Audit::OwnershipResolver.resolve!(record)
      snapshot = record.attributes.except(*record.class.paper_trail_options.fetch(:skip)).compact

      AuditVersion.create!(
        item_type: record.class.base_class.name,
        item_subtype: record.class.name,
        item_id: record.id,
        event: :create,
        operation: Audit::Operation.ensure_persisted!,
        owner_id: ownership.owner_id,
        context_id: ownership.context_id,
        mutation_source: Audit::Current.mutation_source.presence || "unknown",
        whodunnit: PaperTrail.request.whodunnit,
        object_changes: snapshot.transform_values { |value| [ nil, value ] },
        metadata: Audit::VersionMetadata.for(record)
      )
    end
  end
end
