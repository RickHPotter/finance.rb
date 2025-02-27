# frozen_string_literal: true

module Logic
  class CashInstallments
    def self.find_ref_month_year_by_params(user, params)
      params = params.symbolize_keys
      month_year = params.delete(:month_year)
      year = month_year[0..3]
      month = month_year[4..]
      search_term = params.delete(:search_term) || ""

      search_term_condition = "cash_transactions.description ILIKE '%#{search_term}%'" if search_term.present?
      conditions = build_conditions_from_params(params)
      inclusions = { cash_transaction: %i[categories entities] }

      user.cash_installments
          .where.not(price: 0)
          .joins(:cash_transaction)
          .select("installments.*,
                  SUM(installments.price)
                  OVER (PARTITION BY cash_transactions.user_id ORDER BY installments.date ASC, installments.cash_installments_count ASC, installments.price DESC)
                  + #{initial_balance(user, month, year)} AS balance")
          .includes(inclusions)
          .where(conditions)
          .where(search_term_condition)
          .where("installments.date_year = ? AND installments.date_month = ?", year, month)
          .order("installments.date ASC, installments.cash_installments_count DESC, installments.price ASC")
    end

    def self.initial_balance(user, month, year)
      user.cash_installments
          .where("installments.date_year < :year OR installments.date_year = :year AND installments.date_month < :month", month:, year:)
          .sum("installments.price")
    end

    def self.build_conditions_from_params(params)
      params.delete(:controller)
      params.delete(:action)

      return {} if params.blank?

      associations = build_conditions_for_associoations(params)

      params[:price] = build_price_range_conditions(params)
      params[:cash_installments_count] = build_installments_count_range_conditions(params)
      installments_price = build_cash_transaction_price_range_conditions(params)

      {
        price: installments_price,
        cash_transaction: { **params.compact_blank, **associations.compact_blank }.compact_blank
      }.compact_blank
    end

    def self.build_cash_transaction_price_range_conditions(params)
      from_ct_price = params.delete(:from_ct_price).to_i
      to_ct_price = params.delete(:to_ct_price).to_i
      return nil if from_ct_price.zero? && to_ct_price.zero?

      from_ct_price ||= 0
      to_ct_price   ||= from_ct_price if from_ct_price
      from_ct_price, to_ct_price = to_ct_price, from_ct_price if from_ct_price > to_ct_price

      (from_ct_price..to_ct_price)
    end

    def self.build_price_range_conditions(params)
      from_price = params.delete(:from_price).to_i
      to_price = params.delete(:to_price).to_i
      return nil if from_price.zero? && to_price.zero?

      from_price ||= 0
      to_price   ||= from_price if from_price
      from_price, to_price = to_price, from_price if from_price > to_price

      (from_price..to_price)
    end

    def self.build_installments_count_range_conditions(params)
      from_installments_count = params.delete(:from_installments_count).to_i
      to_installments_count = params.delete(:to_installments_count).to_i
      return nil if from_installments_count.zero? && to_installments_count.zero?

      from_installments_count ||= 1
      to_installments_count   ||= from_installments_count if from_installments_count
      from_installments_count, to_installments_count = to_installments_count, from_installments_count if from_installments_count > to_installments_count

      (from_installments_count..to_installments_count)
    end

    def self.build_conditions_for_associoations(params)
      category_id = (params.delete(:category_id) || params.delete(:category_ids) || {}).compact_blank
      entity_id = (params.delete(:entity_id) || params.delete(:entity_ids) || {}).compact_blank

      {
        category_transactions: { category_id: }.compact_blank,
        entity_transactions: { entity_id: }.compact_blank
      }.compact_blank
    end
  end
end
