# frozen_string_literal: true

class HealthCheck::Repairs::LockSet
  LOCKABLE_TYPES = %w[
    CardInstallment
    CardTransaction
    CashInstallment
    CashTransaction
    Context
    EntityTransaction
    Exchange
    Message
  ].freeze

  attr_reader :preview

  def initialize(preview:)
    @preview = preview
  end

  def call
    identities.group_by(&:first).sort.each do |record_type, entries|
      record_type.constantize.unscoped.where(id: entries.map(&:last).uniq.sort).order(:id).lock.load
    end
  end

  private

  def identities
    @identities ||= begin
      values = preview.changes.each_with_object([]) do |change, collected|
        collected << identity(change.record_type, change.record_id)
        collected << reference_identity(change.before)
        collected << reference_identity(change.after)
      end
      preview.references.each { |reference| values.concat(reference_identities(reference)) }
      values << identity("Context", preview.scope.context.id)
      values.compact.uniq.sort_by { |record_type, record_id| [ record_type, record_id ] }
    end
  end

  def reference_identities(reference)
    return [] unless reference.is_a?(Hash)

    record_type = reference["type"]
    [
      identity(record_type, reference["id"]),
      *Array(reference["ids"]).filter_map { |record_id| identity(record_type, record_id) }
    ]
  end

  def reference_identity(value)
    return unless value.is_a?(Hash)

    identity(value["type"], value["id"])
  end

  def identity(record_type, record_id)
    return unless record_type.to_s.in?(LOCKABLE_TYPES)

    normalized_id = Integer(record_id, exception: false)
    [ record_type.to_s, normalized_id ] if normalized_id&.positive?
  end
end
