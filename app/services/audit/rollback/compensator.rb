# frozen_string_literal: true

class Audit::Rollback::Compensator
  class CompensationError < StandardError; end

  TRANSACTION_TYPES = %w[CashTransaction CardTransaction].freeze
  INSTALLMENT_TYPES = %w[CashInstallment CardInstallment].freeze

  attr_reader :preview, :confirmed, :impact, :handled_keys

  def initialize(preview:, confirmed:)
    @preview = preview
    @confirmed = confirmed
    @impact = Audit::Rollback::Impact.new(preview:)
    @handled_keys = Set.new
  end

  def call
    parent_groups.sort.each do |(record_type, item_id), rows|
      compensate_parent(record_type:, item_id:, rows:)
    end
    ensure_every_action_handled!
    impact
  end

  private

  def parent_groups
    @parent_groups ||= preview.rows.each_with_object({}) do |row, groups|
      parent_key = parent_key_for(row)
      groups[parent_key] ||= []
      groups[parent_key] << row
    end
  end

  def parent_key_for(row)
    return [ row.record_type, row.item_id ] if row.record_type.in?(TRANSACTION_TYPES)

    dependency = row.dependencies.find { |candidate| candidate.relationship == "parent" }
    raise CompensationError, "installment parent is unavailable" unless dependency

    [ dependency.record_type, dependency.item_id ]
  end

  def compensate_parent(record_type:, item_id:, rows:)
    parent_row = rows.find { |row| row.record_type == record_type && row.item_id == item_id }
    installment_rows = rows.select { |row| row.record_type.in?(INSTALLMENT_TYPES) }
    action = parent_row&.action

    case action
    when "destroy" then destroy_parent(parent_row, installment_rows)
    when "recreate" then recreate_parent(parent_row, installment_rows)
    else update_parent(record_type:, item_id:, parent_row:, installment_rows:)
    end
  end

  def destroy_parent(parent_row, installment_rows)
    parent = parent_row.adapter.live_record
    raise CompensationError, "rollback target is missing" unless parent

    impact.capture_transaction(parent)
    prepare_parent(parent)
    parent.destroy!
    mark_handled(parent_row, *installment_rows)
  end

  def recreate_parent(parent_row, installment_rows)
    parent = parent_row.record_type.constantize.new(parent_row.adapter.restore_attributes.merge("id" => parent_row.item_id))
    association = installment_association(parent)
    parent.public_send(association).target.clear
    installment_rows.select { |row| row.before_state.present? }.each do |row|
      parent.public_send(association).build(installment_attributes(row))
    end
    prepare_parent(parent)
    parent.save!
    impact.capture_transaction(parent)
    mark_handled(parent_row, *installment_rows)
  end

  def update_parent(record_type:, item_id:, parent_row:, installment_rows:)
    parent = parent_row&.adapter&.live_record || record_type.constantize.unscoped.find_by(id: item_id)
    raise CompensationError, "installment parent is missing" unless parent

    impact.capture_transaction(parent)
    parent.assign_attributes(parent_row.adapter.restore_attributes) if parent_row&.action == "update"
    apply_installment_changes(parent, installment_rows)
    return mark_handled(parent_row, *installment_rows) unless parent.changed? || nested_changes?(parent)

    prepare_parent(parent)
    parent.save!
    mark_handled(parent_row, *installment_rows)
  end

  def apply_installment_changes(parent, rows)
    association = parent.public_send(installment_association(parent))
    rows.each do |row|
      case row.action
      when "update"
        find_installment!(association, row).assign_attributes(row.adapter.restore_attributes)
      when "destroy"
        find_installment!(association, row).mark_for_destruction
      when "recreate"
        association.build(installment_attributes(row))
      end
    end
  end

  def find_installment!(association, row)
    association.detect { |installment| installment.id == row.item_id } ||
      raise(CompensationError, "rollback installment #{row.key} is missing")
  end

  def installment_attributes(row)
    count_attribute = row.record_type == "CashInstallment" ? "cash_installments_count" : "card_installments_count"
    row.adapter.restore_attributes.merge("id" => row.item_id, count_attribute => 1)
  end

  def installment_association(parent)
    parent.is_a?(CashTransaction) ? :cash_installments : :card_installments
  end

  def nested_changes?(parent)
    parent.public_send(installment_association(parent)).any? { |installment| installment.changed? || installment.marked_for_destruction? }
  end

  def prepare_parent(parent)
    parent.historical_correction_confirmation = confirmed
    parent.skip_post_commit_financial_recalculation = true
  end

  def mark_handled(*rows)
    rows.compact.each { |row| handled_keys << row.key }
  end

  def ensure_every_action_handled!
    actionable_keys = preview.rows.reject { |row| row.action == "none" }.map(&:key)
    missing_keys = actionable_keys - handled_keys.to_a
    raise CompensationError, "unhandled rollback rows: #{missing_keys.join(', ')}" if missing_keys.present?
  end
end
