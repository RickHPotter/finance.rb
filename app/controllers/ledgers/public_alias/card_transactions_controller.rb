# frozen_string_literal: true

class Ledgers::PublicAlias::CardTransactionsController < Ledgers::CardTransactionsController
  include Ledgers::PublicAliasAccess
end
