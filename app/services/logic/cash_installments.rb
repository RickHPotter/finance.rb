# frozen_string_literal: true

module Logic
  class CashInstallments
    def self.find_by_span(current_user, span)
      l_date = Date.current.prev_month((span / 2) + 1).beginning_of_month
      r_date = Date.current.next_month((span / 2) - 1).end_of_month

      current_user
        .cash_installments
        .includes(cash_transaction: %i[categories entities])
        .joins(:cash_transaction)
        .where("MAKE_DATE(installments.year, installments.month, 1) BETWEEN ? AND ?", l_date, r_date)
        .order("installments.date DESC")
        .group_by { |t| Date.new(t.year, t.month) }
        .sort
        .reverse
    end
  end
end
