# frozen_string_literal: true

# Controller for CashTransaction
class CashTransactionsController < ApplicationController
  def index
    @cash_installments = current_user
                         .cash_installments
                         .includes(cash_transaction: %i[categories entities])
                         .joins(:cash_transaction)
                         .order("cash_transactions.date DESC")
                         .group_by { |t| "#{t.date.year}/#{format('%02d', t.date.month)}" }
  end
end
