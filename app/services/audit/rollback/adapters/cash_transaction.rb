# frozen_string_literal: true

class Audit::Rollback::Adapters::CashTransaction < Audit::Rollback::Adapters::Base
  SPECIAL_GRAPH_ATTRIBUTES = %w[
    cash_transaction_type friend_notification_intent investment_type_id reference_transactable_id
    reference_transactable_type subscription_id user_card_id
  ].freeze
  DERIVED_ATTRIBUTES = (Audit::Rollback::Adapters::Base::DERIVED_ATTRIBUTES + %w[cash_installments_count]).freeze
  CASH_RECALCULATIONS = %w[cash_installment_order cash_balance user_bank_account_totals].freeze

  def support_issues
    attributes = SPECIAL_GRAPH_ATTRIBUTES.select { |attribute| historical_state[attribute].present? }
    issues = attributes.present? ? [ issue(:unsupported_transaction_graph, attributes:) ] : []
    issues << issue(:incomplete_transaction_graph) if action == "recreate" && historical_installments.empty?
    issues
  end

  def dependencies
    return [] if current_record.nil?

    @dependencies ||= dependent_identities.map do |record_type, dependent_id|
      dependency(record_type:, item_id: dependent_id, relationship: :dependent)
    end.sort_by(&:key)
  end

  def recalculations
    CASH_RECALCULATIONS
  end

  private

  def ignored_attributes
    DERIVED_ATTRIBUTES
  end

  def historical_state
    expected_after_state || before_state || {}
  end

  def historical_installments
    transitions.select do |candidate|
      candidate.record_type == "CashInstallment" &&
        candidate.before_state&.fetch("cash_transaction_id", nil) == item_id
    end
  end

  def paid_history?
    super || current_record&.paid_history? || false
  end

  def dependent_identities
    dependent_scopes.flat_map do |record_type, scope|
      scope.pluck(:id).map { |id| [ record_type, id ] }
    end.uniq
  end

  def dependent_scopes
    {
      "CashInstallment" => CashInstallment.unscoped.where(installment_type: "CashInstallment", cash_transaction_id: item_id),
      "CardInstallment" => CardInstallment.unscoped.where(installment_type: "CardInstallment", cash_transaction_id: item_id),
      "CategoryTransaction" => CategoryTransaction.where(transactable_type: "CashTransaction", transactable_id: item_id),
      "EntityTransaction" => EntityTransaction.where(transactable_type: "CashTransaction", transactable_id: item_id),
      "Exchange" => Exchange.where(cash_transaction_id: item_id),
      "Investment" => Investment.where(cash_transaction_id: item_id).or(Investment.where(piggy_bank_return_cash_transaction_id: item_id)),
      "PiggyBank" => PiggyBank.where(source_cash_transaction_id: item_id).or(PiggyBank.where(return_cash_transaction_id: item_id)),
      "CardTransaction" => CardTransaction.where(advance_cash_transaction_id: item_id)
    }
  end
end
