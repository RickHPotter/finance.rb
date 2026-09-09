# frozen_string_literal: true

module Reports
  class Drilldowns
    INDEX_STATE_VALUE_COUNT = 1
    CHUNK_SIZE = Navigation::State::MAX_VALUES - INDEX_STATE_VALUE_COUNT

    attr_reader :rows, :return_to

    def initialize(rows:, return_to:)
      @rows = rows
      @return_to = return_to
    end

    def call
      {
        cash: serialize_type(cash_rows, :cash),
        card: serialize_type(card_rows, :card)
      }
    end

    private

    def cash_rows
      rows.select { |row| row.installment_type == "CashInstallment" }
    end

    def card_rows
      rows.select { |row| row.installment_type == "CardInstallment" }
    end

    def serialize_type(type_rows, type)
      ordered_rows = type_rows.sort_by(&:installment_id)
      {
        count: ordered_rows.size,
        amount_cents: ordered_rows.sum { |row| row.amount_cents.abs },
        chunks: ordered_rows.each_slice(CHUNK_SIZE).map { |chunk| serialize_chunk(chunk, type) }
      }
    end

    def serialize_chunk(chunk, type)
      {
        count: chunk.size,
        amount_cents: chunk.sum { |row| row.amount_cents.abs },
        path: index_path(type, chunk.map(&:installment_id))
      }
    end

    def index_path(type, installment_ids)
      routes = Rails.application.routes.url_helpers
      return routes.cash_transactions_path(all_month_years: true, cash_transaction: { cash_installment_ids: installment_ids }, return_to:) if type == :cash

      routes.card_transactions_path(all_month_years: true, card_transaction: { card_installment_ids: installment_ids }, return_to:)
    end
  end
end
