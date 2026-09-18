# frozen_string_literal: true

class PiggyBankReconciliation
  # @extends ..................................................................
  # @includes .................................................................
  include ActiveModel::Model
  include ActiveModel::Attributes

  # @security (i.e. attr_accessible) ..........................................
  # @relationships ............................................................
  # @validations ..............................................................
  attribute :return_cash_transaction_id, :integer
  attribute :observed_on, :date
  attribute :observed_net, :string
  attribute :observed_net_cents, :integer
  attribute :description, :string
  attribute :digest, :string

  # @callbacks ................................................................
  # @scopes ...................................................................
  # @additional_config ........................................................
  # @class_methods ............................................................
  # @public_instance_methods ..................................................

  def add_plan_errors(plan)
    return if plan.blank? || plan.valid?

    message = I18n.t("piggy_bank_reconciliations.reasons.#{plan.reason_code}", default: plan.reason_code.to_s.humanize)
    case plan.reason_code
    when :invalid_observation_date
      errors.add(:observed_on, message)
    when :invalid_observed_value
      errors.add(:observed_net, message)
    else
      errors.add(:base, message)
    end
  end

  def add_result_errors(result)
    return if result.blank? || result.success?

    if result.stale?
      errors.add(:base, I18n.t("piggy_bank_reconciliations.reasons.stale_preview"))
    elsif result.reason_code.present?
      message = I18n.t("piggy_bank_reconciliations.reasons.#{result.reason_code}", default: result.reason_code.to_s.humanize)
      errors.add(:base, message)
    else
      errors.add(:base, I18n.t("piggy_bank_reconciliations.reasons.unexpected_failure"))
    end
  end

  # @protected_instance_methods ...............................................
  # @private_instance_methods .................................................
end
