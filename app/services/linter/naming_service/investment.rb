# frozen_string_literal: true

module Linter
  class NamingService::Investment < Base
    attr_reader :cash_transactions, :user

    def initialize(cash_transactions:, user: nil, dry_run: false, locale: nil)
      super(dry_run:, locale:)
      @cash_transactions = cash_transactions.presence || user&.cash_transactions&.investment || CashTransaction.none
      @user = user
    end

    def call
      cash_transactions.select(&:investment?).map do |cash_transaction|
        description = with_record_locale(cash_transaction) do
          cash_transaction.investments.min_by(&:date)&.cash_transaction_description
        end

        annotate(description.present? ? apply_update(cash_transaction, description:) : no_change(cash_transaction))
      end
    end

    private

    def annotate(result)
      result.merge(convention: :investment)
    end
  end
end
