# frozen_string_literal: true

module Linter
  class NamingService::ExchangeReturn < Base
    attr_reader :cash_transactions, :user

    def initialize(cash_transactions:, user: nil, dry_run: false, locale: nil)
      super(dry_run:, locale:)
      @cash_transactions = cash_transactions.presence || user&.cash_transactions&.exchange_return || CashTransaction.none
      @user = user
    end

    def call
      cash_transactions.select(&:exchange_return?).map do |cash_transaction|
        description = with_record_locale(cash_transaction) do
          normalized_description_for(cash_transaction)
        end

        annotate(description.present? ? apply_update(cash_transaction, description:) : no_change(cash_transaction))
      end
    end

    private

    def annotate(result)
      result.merge(convention: :exchange_return, metadata: exchange_metadata(result))
    end

    def exchange_metadata(result)
      cash_transaction = cash_transactions.find { |transaction| transaction.id == result.dig(:record, :id) }
      exchange = cash_transaction&.exchanges&.first
      entity_transaction = exchange&.entity_transaction
      card_transaction = entity_transaction&.transactable

      {
        group_key: [
          card_transaction&.id || "missing-card-transaction",
          entity_transaction&.id || "missing-entity-transaction"
        ].join(":"),
        card_transaction: {
          id: card_transaction&.id,
          description: card_transaction&.description,
          installments_count: card_transaction&.installments_count,
          exchanges_count: entity_transaction&.exchanges_count,
          entity_name: entity_transaction&.entity&.entity_name
        },
        entity_transaction: {
          id: entity_transaction&.id,
          exchanges_count: entity_transaction&.exchanges_count
        }
      }
    end

    def normalized_description_for(cash_transaction)
      return cash_transaction.description unless cash_transaction.exchanges.first&.standalone?

      exchange = cash_transaction.exchanges.first
      count = exchange&.entity_transaction&.exchanges_count.to_i
      return if count.zero?

      base_description = exchange.transactable&.description || cash_transaction.description.to_s.sub(%r{\s+\d+/\d+\z}, "")
      return base_description if count == 1

      "#{base_description} #{exchange.number}/#{count}"
    end
  end
end
