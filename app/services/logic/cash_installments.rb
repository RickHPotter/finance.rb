# frozen_string_literal: true

module Logic
  class CashInstallments
    # def self.find_ref_month_year_by_params(user, params)
    #   params = params.symbolize_keys
    #   month_year = params.delete(:month_year)
    #   year = month_year[0..3]
    #   month = month_year[4..]
    #   search_term = params.delete(:search_term) || ""
    #
    #   search_term_condition = "cash_transactions.description ILIKE '%#{search_term}%'" if search_term.present?
    #   conditions = build_conditions_from_params(params)
    #   inclusions = { cash_transaction: %i[categories entities] }
    #
    #   user.cash_installments
    #       .where.not(price: 0)
    #       .left_outer_joins(inclusions)
    #       .select("installments.*,
    #               cash_transactions.description AS description,
    #               SUM(installments.price)
    #               OVER (PARTITION BY cash_transactions.user_id ORDER BY installments.date, installments.id)
    #               + #{calculate_initial_balance_for_cash_installments(user, month, year)} AS balance")
    #       .includes(inclusions)
    #       .where(conditions)
    #       .where(search_term_condition)
    #       .where("installments.date_year = ? AND installments.date_month = ?", year, month)
    #       .order("installments.date, installments.id")
    # end

    def self.find_by_ref_month_year(user, month, year, raw_conditions)
      search_term_condition = "cash_transactions.description ILIKE '%#{raw_conditions[:search_term]}%'" if raw_conditions[:search_term].present?

      conditions = {
        price: raw_conditions[:installments_price],
        cash_transaction: { **raw_conditions.slice(:cash_installments_count, :price).compact_blank,
                            **raw_conditions[:associations] }.compact_blank
      }.compact_blank

      fetch_cash_installments(user, month, year, conditions, search_term_condition)
    end

    def self.fetch_cash_installments(user, month, year, conditions, search_term_condition)
      initial_balance = calculate_initial_balance_for_cash_installments(user, year, month)

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

    def self.calculate_initial_balance_for_cash_installments(user, year, month)
      past_installments = user.cash_installments.where("date_year < ? OR (date_year = ? AND date_month < ?)", year, year, month).sum(:price)
      past_budgets      = user.budgets.where("year < ? OR (year = ? AND month < ?)", year, year, month).sum(:remaining_value)

      past_installments + past_budgets
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
