# frozen_string_literal: true

module Logic
  class BudgetMatching
    Entry = Data.define(:installment, :amount_cents, :exchange_adjustment_cents) do
      delegate :paid?, to: :installment

      def transaction = installment.transactable
      def installment_type = installment.class.name
      def installment_id = installment.id
      def transaction_type = transaction.class.name
      def transaction_id = transaction.id
    end

    attr_reader :budget

    def initialize(budget:)
      @budget = budget
    end

    def call
      (entries_for(cash_installments) + entries_for(card_installments)).sort_by do |entry|
        [ entry.installment.date, entry.installment_type, entry.installment_id ]
      end
    end

    def matching_card_installments
      card_installments
    end

    private

    def cash_installments
      matching_relation(
        budget.context.cash_installments.includes(cash_transaction: { entity_transactions: :exchanges })
      )
    end

    def card_installments
      matching_relation(
        budget.context.card_installments.includes(card_transaction: { entity_transactions: :exchanges })
      )
    end

    def matching_relation(relation)
      relation = relation.where(month: budget.month, year: budget.year)
      relation = relation.where(number: 1) if budget.first_installment_only?

      filtered_relation(relation).distinct
    end

    def filtered_relation(relation)
      if budget.inclusive? && category_ids.present? && entity_ids.present?
        relation.by_categories_and_entities(category_ids, entity_ids)
      elsif category_ids.present? && entity_ids.present?
        relation.by_categories_or_entities(category_ids, entity_ids)
      elsif category_ids.present?
        relation.by_categories(category_ids)
      elsif entity_ids.present?
        relation.by_entities(entity_ids)
      else
        relation.none
      end
    end

    def category_ids
      @category_ids ||= active_allocations(budget.budget_categories).filter_map(&:category_id).uniq
    end

    def entity_ids
      @entity_ids ||= active_allocations(budget.budget_entities).filter_map(&:entity_id).uniq
    end

    def active_allocations(allocations)
      allocations.reject { |allocation| allocation.marked_for_destruction? || allocation.destroyed? }
    end

    def entries_for(installments)
      installments.map do |installment|
        adjustment = exchange_adjustment_cents(installment)
        Entry.new(installment:, amount_cents: installment.price.to_i - adjustment, exchange_adjustment_cents: adjustment)
      end
    end

    def exchange_adjustment_cents(installment)
      installment.transactable.entity_transactions.filter_map do |entity_transaction|
        next unless entity_transaction.exchanges_count.to_i.positive?

        entity_transaction.exchanges.select { |exchange| exchange.year == budget.year && exchange.month == budget.month }.sum(&:price)
      end.sum * -1
    end
  end
end
