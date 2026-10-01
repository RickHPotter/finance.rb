# frozen_string_literal: true

module Logic
  class CashInstallments
    def self.find_by_ref_month_year(financial_scope, month, year, raw_conditions)
      category_ids = raw_conditions.dig(:associations, :categories, :id).presence
      entity_ids = raw_conditions.dig(:associations, :entities, :id).presence
      conditions = build_conditions(raw_conditions)

      fetch_cash_installments(
        financial_scope,
        month,
        year,
        {
          conditions:,
          search_term: raw_conditions[:search_term],
          category_ids:,
          entity_ids:,
          ids: raw_conditions[:cash_installment_ids],
          attach_to_subscription_id: raw_conditions[:attach_to_subscription_id],
          exchange_bound_type: raw_conditions[:exchange_bound_type],
          sort: raw_conditions[:sort],
          direction: raw_conditions[:direction]
        }
      )
    end

    def self.find_by_query(financial_scope, entity_id, query)
      relation = cash_installments_relation(financial_scope)
                 .includes(cash_transaction: %i[category_transactions entity_transactions])
                 .where(cash_transaction: { entity_transactions: { entity_id: } })

      Search::NormalizedText.apply(relation, query, "cash_transactions.description")
    end

    def self.fetch_cash_installments(financial_scope, month, year, options)
      relation = base_fetch_relation(financial_scope, month, year, options[:conditions])
      relation = apply_composite_search(relation, financial_scope, options[:search_term])
      relation = apply_allocation_filters(relation, financial_scope, options[:category_ids], options[:entity_ids])

      if options[:attach_to_subscription_id].present?
        relation = relation.where(cash_transaction_id: financial_scope.cash_transactions.subscription_candidates.select(:id))
      end

      relation = relation.where(id: options[:ids]) if options[:ids].present?
      relation = apply_exchange_bound_type_filter(relation, options[:exchange_bound_type])
      relation = relation.distinct
      apply_sort(relation, sort: options[:sort], direction: options[:direction])
    end

    def self.base_fetch_relation(financial_scope, month, year, conditions)
      cash_installments_relation(financial_scope)
        .left_joins(cash_transaction: %i[categories entities])
        .where(year:, month:)
        .includes(cash_transaction: [
                    { categories: :parent_category },
                    :entities,
                    { category_transactions: { category: :parent_category } },
                    { entity_transactions: :entity },
                    { line_items: [ { categories: :parent_category }, :entities ] }
                  ])
        .preload(cash_transaction: :reference_transactable)
        .where(conditions)
    end

    def self.apply_composite_search(relation, financial_scope, search_term)
      return relation if search_term.blank?

      matching_line_item_tx_ids = Search::NormalizedText.apply(
        LineItem.where(transactable_type: "CashTransaction"),
        search_term,
        "line_items.description"
      ).select(:transactable_id)

      matching_tx_ids = Search::NormalizedText.apply(
        financial_scope.cash_transactions,
        search_term,
        "cash_transactions.description"
      ).select(:id)

      all_matching_tx_ids = financial_scope.cash_transactions
                                           .where(id: matching_tx_ids)
                                           .or(financial_scope.cash_transactions.where(id: matching_line_item_tx_ids))
                                           .select(:id)

      relation.where(cash_transaction_id: all_matching_tx_ids)
    end

    def self.apply_allocation_filters(relation, financial_scope, category_ids, entity_ids)
      relation = relation.where(cash_transaction_id: financial_scope.cash_transactions.matching_category_ids(category_ids)) if category_ids.present?
      relation = relation.where(cash_transaction_id: financial_scope.cash_transactions.matching_entity_ids(entity_ids)) if entity_ids.present?
      relation
    end

    def self.build_conditions(raw_conditions)
      paid_filters = IndexState::CashTransactions.resolve_paid_filters(
        paid_state: raw_conditions[:paid_state],
        paid: raw_conditions[:paid],
        pending: raw_conditions[:pending]
      )
      paid = paid_filters[:paid] if paid_filters[:paid] != paid_filters[:pending]
      associations_conditions = raw_conditions[:associations]&.except(:categories, :entities) || {}

      conditions = {
        price: raw_conditions[:installments_price],
        number: raw_conditions[:installments_number],
        date: raw_conditions[:date],
        cash_transaction: { **raw_conditions.slice(:cash_installments_count, :id, :price, :subscription_id, :user_bank_account_id).compact_blank,
                            **associations_conditions }.compact_blank
      }.compact_blank

      conditions.merge!(paid:) if paid.in?([ true, false ])
      conditions
    end

    def self.apply_exchange_bound_type_filter(relation, exchange_bound_type)
      return relation if exchange_bound_type.blank? || exchange_bound_type == "all"

      relation.left_joins(cash_transaction: :exchanges)
              .where(exchanges: { bound_type: exchange_bound_type })
              .distinct
    end

    def self.apply_sort(relation, sort:, direction:)
      direction = direction == "desc" ? "DESC" : "ASC"

      case sort
      when "description"
        relation.select("installments.*", "cash_transactions.description")
                .order(Arel.sql("cash_transactions.description #{direction}, installments.id #{direction}"))
      when "installment_date"
        relation.order(Arel.sql("installments.date #{direction}, installments.order_id #{direction}, installments.id #{direction}"))
      when "transaction_date"
        relation.select("installments.*", "cash_transactions.date")
                .order(Arel.sql("cash_transactions.date #{direction}, installments.id #{direction}"))
      when "price"
        relation.order(Arel.sql("installments.price #{direction}, installments.id #{direction}"))
      else
        relation.order(order_id: :asc)
      end
    end

    def self.cash_installments_relation(financial_scope)
      financial_scope.cash_installments
    end
  end
end
