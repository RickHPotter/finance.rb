# frozen_string_literal: true

module Logic
  class CashInstallments
    def self.find_by_ref_month_year(user, month, year, raw_conditions)
      search_term_condition = "cash_transactions.description ILIKE '%#{raw_conditions[:search_term]}%'" if raw_conditions[:search_term].present?

      conditions = {
        price: raw_conditions[:installments_price],
        cash_transaction: { **raw_conditions.slice(:cash_installments_count, :price).compact_blank,
                            **raw_conditions[:associations] }.compact_blank
      }.compact_blank

      fetch_cash_installments(user, month, year, conditions, search_term_condition)
    end

    def self.find_by_query(user, entity_id, query)
      user
        .cash_installments
        .includes(cash_transaction: %i[category_transactions entity_transactions])
        .where(cash_transaction: { entity_transactions: { entity_id: } })
        .where("cash_transaction.description ILIKE ?", "%#{query}%")
    end

    def self.fetch_cash_installments(user, month, year, conditions, search_term_condition)
      past_installments = user.cash_installments.where("date_year < ? OR (date_year = ? AND date_month < ?)", year, year, month).sum(:price)
      past_budgets      = user.budgets.where("year < ? OR (year = ? AND month < ?)", year, year, month).sum(:remaining_value)
      initial_balance   = past_installments + past_budgets

      user.cash_installments
          .where(date_year: year, date_month: month)
          .includes({ cash_transaction: %i[categories entities] })
          .select("installments.*,
                  cash_transactions.description AS description,
                  SUM(installments.price) OVER (ORDER BY installments.date, installments.id) + #{initial_balance} AS balance")
          .where(conditions)
          .where(search_term_condition)
          .order(:date, :id)
    end

    def self.build_conditions_from_params(params)
      params.delete(:controller)
      params.delete(:action)

      return {} if params.blank?

      installments_price = build_cash_transaction_price_range_conditions(params)
      params[:price] = build_price_range_conditions(params)
      params[:cash_installments_count] = build_installments_count_range_conditions(params)

      associations = build_conditions_for_associations(params)

      {
        price: installments_price,
        cash_transaction: { **params.compact_blank, **associations.compact_blank }.compact_blank
      }.compact_blank
    end
  end
end
