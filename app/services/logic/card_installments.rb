# frozen_string_literal: true

module Logic
  class CardInstallments
    def self.find_by_span(user_card, span)
      max_date = user_card.card_installments.maximum("MAKE_DATE(installments.year, installments.month, 1)")
      l_date, r_date = RefMonthYear.get_span(Date.current, max_date, span)

      user_card.card_installments
               .includes(card_transaction: %i[categories entities])
               .where("MAKE_DATE(installments.year, installments.month, 1) BETWEEN ? AND ?", l_date, r_date)
               .order("installments.date DESC")
               .group_by { |t| Date.new(t.year, t.month) }
               .sort
               .reverse
    end
  end
end
