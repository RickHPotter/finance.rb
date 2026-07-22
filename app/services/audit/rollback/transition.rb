# frozen_string_literal: true

class Audit::Rollback::Transition
  ACTIONS = %w[destroy update recreate none].freeze

  attr_reader :versions, :record_type, :item_id, :owner_id, :context_id, :before_state, :expected_after_state

  def initialize(versions:)
    @versions = versions.sort_by(&:id)
    first_version = @versions.first
    @record_type = first_version.item_subtype.presence || first_version.item_type
    @item_id = first_version.item_id
    @owner_id = first_version.owner_id
    @context_id = first_version.context_id
    @before_state = normalize(initial_before_state)
    @expected_after_state = normalize(reconstruct_expected_after_state)
  end

  def key
    "#{record_type}:#{item_id}"
  end

  def event_sequence
    versions.map(&:event)
  end

  def action
    return "destroy" if before_state.nil? && expected_after_state.present?
    return "recreate" if before_state.present? && expected_after_state.nil?
    return "none" if before_state == expected_after_state

    "update"
  end

  def ownership_consistent?
    versions.all? { |version| version.owner_id == owner_id && version.context_id == context_id }
  end

  private

  def initial_before_state
    return nil if versions.first.event_create?

    versions.first.object&.to_h
  end

  def reconstruct_expected_after_state
    versions.reduce(initial_before_state) do |state, version|
      case version.event
      when "create" then apply_changes({}, version.object_changes)
      when "update" then apply_changes(state || version.object&.to_h || {}, version.object_changes)
      when "destroy" then nil
      end
    end
  end

  def apply_changes(state, changes)
    changes.to_h.each_with_object(state.to_h.deep_dup) do |(attribute, values), result|
      result[attribute] = Array(values).last
    end
  end

  def normalize(state)
    Audit::Rollback::State.normalize(record_type, state)
  end
end
