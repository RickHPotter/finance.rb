# frozen_string_literal: true

# Controller for CashTransaction
class CashTransactionsController < ApplicationController
  def index
    l_date = Date.current.prev_month(4).beginning_of_month
    r_date = Date.current.next_month(2).end_of_month

    @cash_installments = current_user
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
