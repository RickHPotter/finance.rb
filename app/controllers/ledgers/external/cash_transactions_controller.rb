# frozen_string_literal: true

class Ledgers::External::CashTransactionsController < Ledgers::CashTransactionsController
  include Ledgers::ExternalAccess
end
