# frozen_string_literal: true

class Ledgers::External::CardTransactionsController < Ledgers::CardTransactionsController
  include Ledgers::ExternalAccess
end
