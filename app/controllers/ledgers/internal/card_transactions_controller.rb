# frozen_string_literal: true

class Ledgers::Internal::CardTransactionsController < Ledgers::CardTransactionsController
  include Ledgers::InternalAccess
end
