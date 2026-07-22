# frozen_string_literal: true

class Audit::Rollback::Adapters::CardTransaction < Audit::Rollback::Adapters::Base
  SPECIAL_GRAPH_ATTRIBUTES = %w[advance_cash_transaction_id reference_transactable_id reference_transactable_type subscription_id].freeze
  DERIVED_ATTRIBUTES = (Audit::Rollback::Adapters::Base::DERIVED_ATTRIBUTES + %w[card_installments_count]).freeze
  CARD_RECALCULATIONS = %w[card_installment_cycles cash_balance user_card_totals].freeze

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
    CARD_RECALCULATIONS
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
      candidate.record_type == "CardInstallment" &&
        candidate.before_state&.fetch("card_transaction_id", nil) == item_id
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
      "CardInstallment" => CardInstallment.unscoped.where(installment_type: "CardInstallment", card_transaction_id: item_id),
      "CategoryTransaction" => CategoryTransaction.where(transactable_type: "CardTransaction", transactable_id: item_id),
      "EntityTransaction" => EntityTransaction.where(transactable_type: "CardTransaction", transactable_id: item_id)
    }
  end
end
