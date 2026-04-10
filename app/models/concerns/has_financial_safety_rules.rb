# frozen_string_literal: true

# Shared read-only safety predicates for transaction models backed by installments.
module HasFinancialSafetyRules
  extend ActiveSupport::Concern

  # @public_instance_methods ..................................................
  def paid_history?
    installments.where(paid: true).exists?
  end

  def partially_paid?
    paid_history? && installments.where(paid: false).exists?
  end

  def latest_paid_installment_date
    installments.where(paid: true).pick(Arel.sql("MAX(DATE(date))"))
  end

  def can_edit_unpaid_future_installments?(proposed_dates)
    latest_paid_date = latest_paid_installment_date
    return true if latest_paid_date.blank?

    normalize_proposed_dates(proposed_dates).all? { |date| date > latest_paid_date }
  end

  def can_change_installment_structure?(proposed_dates:)
    can_edit_unpaid_future_installments?(proposed_dates)
  end

  def can_change_allocation?
    !paid_history? || subscription_allocation_bypass?
  end

  def can_destroy_with_history?
    !paid_history?
  end

  # @private_instance_methods .................................................

  private

  def subscription_allocation_bypass?
    return false unless respond_to?(:user)

    relevant_category_ids = persisted_subscription_category_ids
    return false if relevant_category_ids.empty?

    user.categories.where(id: relevant_category_ids, category_name: "SUBSCRIPTION").exists?
  end

  def persisted_subscription_category_ids
    return [] unless respond_to?(:category_transactions)
    return Array(original_categories).compact.uniq if Array(original_categories).present?
    return [] unless persisted?

    category_transactions.class.where(transactable: self).pluck(:category_id).compact.uniq
  end

  def normalize_proposed_dates(proposed_dates)
    Array(proposed_dates).filter_map do |value|
      value = value.date if value.respond_to?(:date) && !value.is_a?(Date) && !value.is_a?(Time) && !value.is_a?(DateTime)

      case value
      when Date
        value
      when Time, DateTime, ActiveSupport::TimeWithZone
        value.to_date
      when String
        Time.zone.parse(value)&.to_date
      end
    end
  end
end
