# frozen_string_literal: true

class HealthCheck::Repairs::ExchangeReturnAllocationPlanner < HealthCheck::Repairs::BasePlanner
  STRATEGIES = %w[match_percentage corrected_value].freeze

  class << self
    def strategies_for(allocation)
      strategies = []
      strategies << "match_percentage" if match_percentage_available?(allocation)
      strategies << "corrected_value" if corrected_value_available?(allocation)
      strategies
    end

    def match_percentage_available?(allocation)
      percentage = matched_percentage(allocation)

      allocation[:friend_notification_intent].in?(%w[loan reimbursement]) &&
        percentage.to_d.positive? &&
        percentage.to_d != allocation[:loan_return_percentage].to_d
    end

    def corrected_value_available?(allocation)
      allocation[:friend_notification_intent] == "loan" &&
        allocation[:calculated_loan_return_percentage].to_d.positive? &&
        allocation[:calculated_price].to_i != allocation[:current_price].to_i
    end

    def matched_percentage(allocation)
      allocation[:matched_loan_return_percentage] || allocation[:calculated_loan_return_percentage]
    end
  end

  def call
    entity_transaction = scoped_entity_transaction
    allocation = live_allocation
    return read_only("finding_not_current", references: references_for(entity_transaction)) if allocation.blank?

    available_strategies = self.class.strategies_for(allocation)
    return read_only("diagnostic_only", references: references_for(entity_transaction, allocation:)) if available_strategies.empty?
    raise ActiveRecord::RecordNotFound unless strategy.in?(available_strategies)

    previewable(
      changes: changes_for(entity_transaction, allocation),
      references: references_for(entity_transaction, allocation:),
      paid_history: { affected: false, status: "pending" }
    )
  end

  private

  def scoped_entity_transaction
    @scoped_entity_transaction ||= begin
      record = EntityTransaction.includes(:exchanges, :transactable).find(finding_id)
      transactable = record.transactable
      raise ActiveRecord::RecordNotFound unless transactable.respond_to?(:context_id) && transactable.context_id == scope.context.id

      record
    end
  end

  def live_allocation
    @live_allocation ||= audit_rows
                         .flat_map { |row| Array(row[:source_allocation_rows]) }
                         .find { |allocation| allocation[:entity_transaction_id].to_i == finding_id }
  end

  def audit_rows
    transaction_ids = scoped_entity_transaction.exchanges
                                               .joins(:cash_transaction)
                                               .where(cash_transactions: { context_id: scope.context.id })
                                               .merge(CashTransaction.exchange_return)
                                               .distinct
                                               .pluck(:cash_transaction_id)

    Logic::ExchangeReturnAudit.new(
      current_user: scope.user,
      current_context: scope.context,
      status_filter: "pending",
      transaction_ids:
    ).call
  end

  def strategy
    @strategy ||= options["strategy"].presence || self.class.strategies_for(live_allocation).first
  end

  def changes_for(entity_transaction, allocation)
    attributes_for(allocation).filter_map do |attribute, after|
      before = entity_transaction.public_send(attribute)
      next if values_equal?(before, after)

      change(
        record_type: "EntityTransaction",
        record_id: entity_transaction.id,
        attribute:,
        before:,
        after:,
        metadata: {
          strategy:,
          transactable_type: entity_transaction.transactable_type,
          transactable_id: entity_transaction.transactable_id
        }
      )
    end
  end

  def attributes_for(allocation)
    return { loan_return_percentage: self.class.matched_percentage(allocation) } if strategy == "match_percentage"

    {
      loan_return_percentage: allocation[:calculated_loan_return_percentage],
      price: allocation[:calculated_price],
      price_to_be_returned: allocation[:calculated_price]
    }
  end

  def values_equal?(before, after)
    before.to_d == after.to_d
  end

  def references_for(entity_transaction, allocation: nil)
    [
      {
        type: entity_transaction.transactable_type,
        id: entity_transaction.transactable_id,
        role: "allocation_source"
      },
      {
        type: "CashTransaction",
        ids: audit_rows.map { |row| row[:id] },
        role: "affected_exchange_returns",
        issue_code: allocation&.dig(:issue_code)
      }
    ]
  end
end
