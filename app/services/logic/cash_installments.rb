# frozen_string_literal: true

module Logic
  class CashInstallments
    def self.find_by_ref_month_year(financial_scope, month, year, raw_conditions)
      search_term_condition = "cash_transactions.description ILIKE '%#{raw_conditions[:search_term]}%'" if raw_conditions[:search_term].present?

      case [ raw_conditions[:paid], raw_conditions[:pending] ]
      when %w[false false] then return []
      when %w[true true]   then paid = nil
      when %w[true false]  then paid = true
      when %w[false true]  then paid = false
      end

      conditions = {
        price: raw_conditions[:installments_price],
        number: raw_conditions[:installments_number],
        date: raw_conditions[:date],
        cash_transaction: { **raw_conditions.slice(:cash_installments_count, :price, :user_bank_account_id).compact_blank,
                            **raw_conditions[:associations] }.compact_blank
      }.compact_blank

      conditions.merge!(paid:) if paid.in?([ true, false ])

      fetch_cash_installments(
        financial_scope,
        month,
        year,
        {
          conditions:,
          search_term_condition:,
          ids: raw_conditions[:cash_installment_ids],
          sort: raw_conditions[:sort],
          direction: raw_conditions[:direction]
        }
      )
    end

    def self.find_by_query(financial_scope, entity_id, query)
      cash_installments_relation(financial_scope)
        .includes(cash_transaction: %i[category_transactions entity_transactions])
        .where(cash_transaction: { entity_transactions: { entity_id: } })
        .where("cash_transaction.description ILIKE ?", "%#{query}%")
    end

    def self.fetch_cash_installments(financial_scope, month, year, options)
      relation = cash_installments_relation(financial_scope)
                 .where(year:, month:)
                 .includes(cash_transaction: [
                             :categories,
                             :entities,
                             :card_installments,
                             { category_transactions: :category },
                             { entity_transactions: :entity }
                           ])
                 .where(options[:conditions])
                 .where(options[:search_term_condition])

      relation = relation.where(id: options[:ids]) if options[:ids].present?
      apply_sort(relation, sort: options[:sort], direction: options[:direction])
    end

    def self.apply_sort(relation, sort:, direction:)
      direction = direction == "desc" ? "DESC" : "ASC"

      case sort
      when "description"
        relation.select("installments.*", "cash_transactions.description")
                .order(Arel.sql("cash_transactions.description #{direction}, installments.id #{direction}"))
      when "installment_date"
        relation.order(Arel.sql("installments.date #{direction}, installments.id #{direction}"))
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
