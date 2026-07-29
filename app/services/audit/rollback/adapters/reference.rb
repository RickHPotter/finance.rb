# frozen_string_literal: true

class Audit::Rollback::Adapters::Reference < Audit::Rollback::Adapters::Base
  RECALCULATIONS = %w[reference_payment_dates cash_balance].freeze

  def support_issues
    parent_identity.present? ? [] : [ issue(:missing_parent_identity) ]
  end

  def dependencies
    @dependencies ||= begin
      parent_dependencies = if parent_identity.present?
                              [ dependency(record_type: "UserCard", item_id: parent_identity, relationship: :parent) ]
                            else
                              []
                            end
      parent_dependencies + replacement_dependencies
    end
  end

  def conflicts
    super.tap do |issues|
      issues << issue(:reference_merge_routing_conflict) if reference_merge?
      next unless conflicting_records.present?
      next if conflicting_records.all? { |record| replacement_transition_for(record)&.action == "destroy" }

      issues << issue(:reference_key_taken, conflicting_keys: conflicting_records.map { |record| "Reference:#{record.id}" })
    end
  end

  def recalculations
    RECALCULATIONS
  end

  def compensate!(**)
    case action
    when "destroy" then destroy_record!
    when "recreate" then recreate_reference!
    when "update" then update_reference!
    end
  end

  private

  def parent_identity
    historical_state["user_card_id"] || transition.versions.last.metadata["user_card_id"]
  end

  def historical_state
    before_state || expected_after_state || {}
  end

  def dependency_available?(dependency)
    UserCard.unscoped.exists?(id: dependency.item_id)
  end

  def replacement_dependencies
    conflicting_records.filter_map do |record|
      replacement = replacement_transition_for(record)
      next unless replacement&.action == "destroy"

      dependency(record_type: "Reference", item_id: record.id, relationship: :dependent)
    end
  end

  def conflicting_records
    return @conflicting_records if defined?(@conflicting_records)
    return @conflicting_records = [] if action == "destroy" || before_state.blank?

    scope = Reference.unscoped.where(context_id: before_state["context_id"], user_card_id: before_state["user_card_id"]).where.not(id: item_id)
    @conflicting_records = scope.where(
      "(month = :month AND year = :year) OR reference_date = :reference_date",
      month: before_state["month"],
      year: before_state["year"],
      reference_date: before_state["reference_date"]
    ).to_a
  end

  def replacement_transition_for(record)
    transitions.find { |candidate| candidate.record_type == "Reference" && candidate.item_id == record.id }
  end

  def reference_merge?
    reference_actions = transitions.select { |candidate| candidate.record_type == "Reference" }.map(&:action).sort
    return false unless reference_actions == %w[recreate update]

    transitions.any? do |candidate|
      candidate.record_type == "CardInstallment" &&
        candidate.net_changed_attributes.include?("cash_transaction_id")
    end
  end

  def recreate_reference!
    record = record_class.new(restore_attributes.merge("id" => item_id))
    prepare_reference(record)
    record.save!
  end

  def update_reference!
    raise ActiveRecord::RecordNotFound, "Reference #{item_id} is missing" unless live_record

    live_record.assign_attributes(restore_attributes)
    prepare_reference(live_record)
    live_record.save!
  end

  def prepare_reference(record)
    record.skip_reference_closing_date_calculation = true
    record.skip_card_payment_date_sync = true
  end
end
