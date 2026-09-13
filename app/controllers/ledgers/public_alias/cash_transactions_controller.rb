# frozen_string_literal: true

class Ledgers::PublicAlias::CashTransactionsController < Ledgers::CashTransactionsController
  include Ledgers::PublicAliasAccess
end
