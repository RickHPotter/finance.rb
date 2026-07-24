# frozen_string_literal: true

class HealthCheck::Repairs::BasePlanner
  attr_reader :finding_id, :options, :scope

  def initialize(scope:, finding_id:, options: {})
    @scope = scope
    @finding_id = Integer(finding_id, exception: false)
    @options = options.to_h.stringify_keys

    raise ActiveRecord::RecordNotFound unless @finding_id&.positive?
  end

  private

  def change(**attributes)
    HealthCheck::Repairs::Change.new(**attributes)
  end

  def previewable(changes:, references: [], warnings: [], paid_history: {})
    HealthCheck::Repairs::Result.new(
      finding_id:,
      state: "previewable",
      changes:,
      references:,
      warnings:,
      paid_history:
    )
  end

  def read_only(reason, changes: [], references: [], warnings: [], paid_history: {})
    HealthCheck::Repairs::Result.new(
      finding_id:,
      state: "read_only",
      changes:,
      references:,
      warnings:,
      paid_history:,
      unavailable_reason: reason
    )
  end
end
