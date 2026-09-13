# frozen_string_literal: true

class Ledgers::Internal::CashTransactionsController < Ledgers::CashTransactionsController
  include Ledgers::InternalAccess
end
