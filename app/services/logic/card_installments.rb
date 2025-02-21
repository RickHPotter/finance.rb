# frozen_string_literal: true

module Logic
  class CardInstallments
    def self.find_by_span(user_card, span)
      max_date = user_card.card_installments.maximum("MAKE_DATE(installments.year, installments.month, 1)")
      return [] if max_date.nil?

      l_date, r_date = RefMonthYear.get_span(Date.current, max_date, span)

      user_card.card_installments
               .includes(card_transaction: %i[categories entities])
               .where("MAKE_DATE(installments.year, installments.month, 1) BETWEEN ? AND ?", l_date, r_date)
               .order("installments.date DESC")
               .group_by { |t| Date.new(t.year, t.month) }
               .sort
               .reverse
    end

    def self.find_by_params(user, params)
      conditions = get_conditions_from_params(params)

      user.card_installments
          .includes(card_transaction: %i[categories entities])
          .where(conditions)
          .order("installments.date DESC")
          .group_by { |t| Date.new(t.year, t.month) }
          .sort
          .reverse
    end

    def self.find_ref_month_year_by_params(user, params)
      month_year = params.delete(:month_year)
      conditions = get_conditions_from_params(params)
      inclusions = { card_transaction: %i[categories entities] }
      inclusions[:card_transaction] << :user_card if params[:user_card_id].blank?

      user.card_installments
          .includes(inclusions)
          .where(conditions)
          .where("TO_CHAR(installments.date, 'YYYYMM') = ?", month_year)
          .order("installments.date DESC")
          .sort
          .reverse
    end

    def self.get_conditions_from_params(params)
      params.delete(:controller)
      params.delete(:action)

      return {} if params.blank?

      category_id = params.delete(:category_id)
      entity_id   = params.delete(:entity_id)

      {
        card_transaction: {
          **params.to_unsafe_h,
          category_transactions: { category_id: }.compact_blank,
          entity_transactions: { entity_id: }.compact_blank
        }.compact_blank
      }
    end
  end
end
