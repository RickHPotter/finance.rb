# frozen_string_literal: true

class AllocationMutations::PaidHistoryEnvelope
  ALLOWED_PARENT_CHANGES = %w[comment date description].freeze
  ALLOWED_INSTALLMENT_CHANGES = %w[date].freeze

  attr_reader :owner

  def initialize(owner)
    @owner = owner
  end

  def safe?
    supported_owner? &&
      owner.persisted? &&
      parent_changes_safe? &&
      installment_structure_intact? &&
      installment_changes_safe? &&
      reference_periods_intact?
  end

  private

  def supported_owner?
    owner.is_a?(CashTransaction) || owner.is_a?(CardTransaction)
  end

  def parent_changes_safe?
    (owner.changes_to_save.keys - ALLOWED_PARENT_CHANGES).empty?
  end

  def installment_structure_intact?
    installments.none?(&:new_record?) && installments.none?(&:marked_for_destruction?)
  end

  def installment_changes_safe?
    installments.all? do |installment|
      (installment.changes_to_save.keys - ALLOWED_INSTALLMENT_CHANGES).empty?
    end
  end

  def reference_periods_intact?
    reference_period_intact?(owner) && installments.all? { |installment| reference_period_intact?(installment) }
  end

  def reference_period_intact?(record)
    record.attribute_in_database("month").to_i == record.month.to_i &&
      record.attribute_in_database("year").to_i == record.year.to_i
  end

  def installments
    @installments ||= owner.installments.to_a
  end
end
