# frozen_string_literal: true

module Linter
  class NamingService < Base
    attr_reader :cash_transactions, :user

    def initialize(cash_transactions: [], user: nil, dry_run: false, locale: nil)
      super(dry_run:, locale:)
      @cash_transactions = Array(cash_transactions).compact
      @user = user
    end

    def call
      [
        NamingService::Investment.new(cash_transactions:, user:, dry_run:, locale:).call,
        NamingService::ExchangeReturn.new(cash_transactions:, user:, dry_run:, locale:).call,
        NamingService::CardPayment.new(cash_transactions:, user:, dry_run:, locale:).call,
        NamingService::CardAdvance.new(cash_transactions:, user:, dry_run:, locale:).call
      ].flatten
    end
  end
end
