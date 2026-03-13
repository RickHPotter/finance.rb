# frozen_string_literal: true

module Linter
  class NamingService::CardAdvance < Base
    attr_reader :cash_transactions, :user

    def initialize(cash_transactions:, user: nil, dry_run: false, locale: nil)
      super(dry_run:, locale:)
      @cash_transactions = cash_transactions.presence || user&.cash_transactions&.card_advance || CashTransaction.none
      @user = user
    end

    def call
      card_transactions_by_cash_transaction_id = related_card_transactions.index_by(&:advance_cash_transaction_id)

      cash_transactions.select(&:card_advance?).flat_map do |cash_transaction|
        with_record_locale(cash_transaction) do
          rename_card_advance_records(cash_transaction, card_transactions_by_cash_transaction_id)
        end
      end
    end

    private

    def rename_card_advance_records(cash_transaction, card_transactions_by_cash_transaction_id)
      card_transaction = card_transactions_by_cash_transaction_id[cash_transaction.id]
      return [ annotate(no_change(cash_transaction)) ] if card_transaction.nil?

      description = card_transaction.card_advance_description

      [
        annotate(apply_update(cash_transaction, description:)),
        annotate(apply_update(card_transaction, description:))
      ]
    end

    def related_card_transactions
      cash_transaction_ids = cash_transactions.select(&:card_advance?).map(&:id)
      return CardTransaction.none if cash_transaction_ids.empty?

      CardTransaction.where(advance_cash_transaction_id: cash_transaction_ids)
    end

    def annotate(result)
      result.merge(convention: :card_advance)
    end
  end
end
