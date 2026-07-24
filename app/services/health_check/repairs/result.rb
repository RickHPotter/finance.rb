# frozen_string_literal: true

HealthCheck::Repairs::Result = Data.define(
  :finding_id,
  :state,
  :changes,
  :references,
  :warnings,
  :paid_history,
  :unavailable_reason
) do
  def initialize(**attributes)
    attributes.assert_valid_keys(:finding_id, :state, :changes, :references, :warnings, :paid_history, :unavailable_reason)
    finding_id = attributes.fetch(:finding_id)
    state = attributes.fetch(:state)
    changes = attributes.fetch(:changes, [])
    references = attributes.fetch(:references, [])
    warnings = attributes.fetch(:warnings, [])
    paid_history = attributes.fetch(:paid_history, {})
    unavailable_reason = attributes[:unavailable_reason]

    raise ArgumentError, "finding_id is required" if finding_id.blank?
    raise ArgumentError, "invalid preview state" unless state.to_s.in?(%w[previewable read_only prohibited])

    normalized_changes = Array(changes)
    raise ArgumentError, "invalid repair change" unless normalized_changes.all?(HealthCheck::Repairs::Change)
    raise ArgumentError, "previewable result requires changes" if state.to_s == "previewable" && normalized_changes.empty?

    super(
      finding_id: finding_id.to_s,
      state: state.to_s,
      changes: normalized_changes.freeze,
      references: HealthCheck::Repairs::Payload.normalize(references),
      warnings: HealthCheck::Repairs::Payload.normalize(warnings),
      paid_history: HealthCheck::Repairs::Payload.normalize(paid_history),
      unavailable_reason: unavailable_reason&.to_s
    )
  end

  def previewable?
    state == "previewable"
  end

  def to_h
    HealthCheck::Repairs::Payload.normalize({
                                              finding_id:,
                                              state:,
                                              changes: changes.map(&:to_h),
                                              references:,
                                              warnings:,
                                              paid_history:,
                                              unavailable_reason:
                                            })
  end
end
