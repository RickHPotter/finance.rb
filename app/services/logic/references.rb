# frozen_string_literal: true

module Logic
  class References
    COMBINE_INTO_TARGET = "combine_into_target"
    REALLOCATE_INSTALLMENTS = "reallocate_installments"
    MERGE_MODES = [ COMBINE_INTO_TARGET, REALLOCATE_INSTALLMENTS ].freeze

    # rubocop:disable Metrics/AbcSize
    # rubocop:disable Naming/PredicateMethod
    # rubocop:disable Metrics/MethodLength
    # rubocop:disable Metrics/BlockLength
    def self.merge(user_card, source_reference_date, target_reference_date, merge_mode:, context: user_card.user.main_context)
      merge_mode = merge_mode.to_s

      return false unless merge_mode.in?(MERGE_MODES)

      source_date = Date.parse(source_reference_date)
      target_date = Date.parse(target_reference_date)

      return false if merge_mode == REALLOCATE_INSTALLMENTS && source_date.next_month != target_date
      return reallocation_result(user_card, source_date, target_date, context:).applied? if merge_mode == REALLOCATE_INSTALLMENTS
      return false unless merge_mode == COMBINE_INTO_TARGET
      return false if source_date.prev_month != target_date && source_date.next_month != target_date

      source_card_payment = user_card.unpaid_invoices(context:).find_by(year: source_date.year, month: source_date.month)
      target_card_payment = user_card.unpaid_invoices(context:).find_by(year: target_date.year, month: target_date.month)
      source_reference = user_card.references.find_by(context:, year: source_date.year, month: source_date.month)
      target_reference = user_card.references.find_by(context:, year: target_date.year, month: target_date.month)

      return false if source_card_payment.nil? || target_card_payment.nil? || source_reference.nil? || target_reference.nil?

      Audit::Operation.run(source: :web, join_existing: false, actor: user_card.user, context:,
                           metadata: combine_metadata(user_card, context, source_date, target_date)) do
        ApplicationRecord.transaction do
          Audit::BulkMutation.update_all!(
            source_card_payment.card_installments,
            year: target_date.year,
            month: target_date.month,
            cash_transaction_id: target_card_payment.id
          )

          new_target_price = target_card_payment.card_installments.reload.sum(:price)
          new_target_comment = target_card_payment.card_installments.first&.comment

          Audit::BulkMutation.update_columns!(target_card_payment, price: new_target_price, comment: new_target_comment)
          Audit::BulkMutation.update_columns!(target_card_payment.cash_installments.first, price: new_target_price) if target_card_payment.cash_installments.any?

          source_card_payment.reload.destroy!

          source_exchanges = Exchange
                             .joins(:entity_transaction)
                             .joins("INNER JOIN card_transactions ON card_transactions.id = entity_transactions.transactable_id " \
                                    "AND entity_transactions.transactable_type = 'CardTransaction'")
                             .where(bound_type: :card_bound, month: source_date.month, year: source_date.year)
                             .where(card_transactions: { user_card_id: user_card.id, context_id: context.id })

          source_exchanges.find_each do |exchange|
            exchange.update!(
              month: target_date.month,
              year: target_date.year,
              date: target_reference.reference_date
            )
          end

          Audit::BulkMutation.update_columns!(target_reference, reference_closing_date: source_reference.reference_closing_date)
          source_reference.destroy!

          min_date = [ source_date, target_date ].min
          Logic::RecalculateBalancesService.new(user: user_card.user, context:, year: min_date.year, month: min_date.month).call
          Audit::Operation.ensure_persisted!
        end
      end

      true
    end

    def self.combine_metadata(user_card, context, source_date, target_date)
      affected_dates = [ source_date, target_date ].sort
      {
        reference_merge_mode: COMBINE_INTO_TARGET,
        user_card_id: user_card.id,
        context_id: context.id,
        source_reference: source_date.iso8601,
        target_reference: target_date.iso8601,
        earliest_affected_reference: affected_dates.first.iso8601,
        latest_affected_reference: affected_dates.last.iso8601,
        tail_reference: affected_dates.last.iso8601
      }
    end
    private_class_method :combine_metadata

    def self.reallocation_result(user_card, source_date, target_date, context:)
      plan = ReferenceMerges::ReallocationPlanner.new(user_card:, context:, source_date:, target_date:).call

      ReferenceMerges::ReallocationApply.new(plan:).call
    end
    # rubocop:enable Naming/PredicateMethod
    # rubocop:enable Metrics/AbcSize
    # rubocop:enable Metrics/MethodLength
    # rubocop:enable Metrics/BlockLength
  end
end
