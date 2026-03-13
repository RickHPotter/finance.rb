# frozen_string_literal: true

module Linter
  class NamingService::CardPayment < Base
    attr_reader :cash_transactions, :user

    def initialize(cash_transactions:, user: nil, dry_run: false, locale: nil)
      super(dry_run:, locale:)
      @cash_transactions = cash_transactions.presence || user&.cash_transactions&.card_payment || CashTransaction.none
      @user = user
    end

    def call
      cash_transactions.select(&:card_payment?).map do |cash_transaction|
        description = with_record_locale(cash_transaction) do
          cash_transaction.card_installments.min_by(&:date)&.cash_transaction_description
        end

        annotate(description.present? ? apply_update(cash_transaction, description:) : no_change(cash_transaction))
      end
    end

    private

    def annotate(result)
      result.merge(convention: :card_payment)
    end
  end
end
