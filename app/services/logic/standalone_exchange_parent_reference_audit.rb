# frozen_string_literal: true

class Logic::StandaloneExchangeParentReferenceAudit
  attr_reader :ids

  def initialize(ids: nil)
    @ids = Array(ids).compact_blank.map(&:to_i)
  end

  def call
    {
      generated_at: Time.current.iso8601,
      candidates:,
      candidate_count: candidates.size,
      supported_count: candidates.count { |candidate| candidate[:supported] },
      skipped_count: candidates.count { |candidate| !candidate[:supported] }
    }
  end

  private

  def candidates
    @candidates ||= target_transactions.map do |transaction|
      parent_candidates = parent_candidates_for(transaction)
      desired_parent = parent_candidates.one? ? parent_candidates.first : nil
      unsupported_reason = unsupported_reason_for(transaction, parent_candidates:, desired_parent:)

      {
        exchange_return_transaction_id: transaction.id,
        user_id: transaction.user_id,
        context_id: transaction.context_id,
        description: transaction.description,
        current_reference: serialize_reference(transaction.reference_transactable),
        desired_reference: serialize_reference(desired_parent),
        standalone_exchange_ids: standalone_monetary_exchanges_for(transaction).map(&:id),
        parent_candidates: parent_candidates.map { |parent| serialize_reference(parent) },
        supported: unsupported_reason.blank?,
        unsupported_reason:
      }
    end
  end

  def target_transactions
    @target_transactions ||= begin
      scope = CashTransaction.includes(exchanges: { entity_transaction: :transactable }).exchange_return.where(reference_transactable: nil).order(:id)
      scope = scope.where(id: ids) if ids.present?

      scope.select { |transaction| standalone_exchange_return_candidate?(transaction) }
    end
  end

  def standalone_exchange_return_candidate?(transaction)
    bound_types = transaction.exchanges.monetary.distinct.pluck(:bound_type)
    bound_types == [ "standalone" ]
  end

  def standalone_monetary_exchanges_for(transaction)
    transaction.exchanges.monetary.standalone.order(:date, :number, :id).to_a
  end

  def parent_candidates_for(transaction)
    standalone_monetary_exchanges_for(transaction)
      .map { |exchange| exchange.entity_transaction&.transactable }
      .compact
      .select { |parent| supported_parent_transaction?(parent) }
      .uniq { |parent| [ parent.class.name, parent.id ] }
  end

  def supported_parent_transaction?(transaction)
    transaction.is_a?(CashTransaction) || transaction.is_a?(CardTransaction)
  end

  def unsupported_reason_for(transaction, parent_candidates:, desired_parent:)
    return "missing_standalone_monetary_exchanges" if standalone_monetary_exchanges_for(transaction).empty?
    return "parent_candidates_not_found" if parent_candidates.empty?
    return "multiple_parent_candidates" if parent_candidates.size > 1
    return "parent_not_exchange_source" unless exchange_source_transaction?(desired_parent)

    nil
  end

  def exchange_source_transaction?(transaction)
    return false if transaction.blank?

    transaction.categories.pluck(:category_name).include?("EXCHANGE")
  end

  def serialize_reference(reference)
    return if reference.blank?

    {
      id: reference.id,
      type: reference.class.name,
      description: reference.try(:description),
      user_id: reference.try(:user_id)
    }.compact
  end
end
