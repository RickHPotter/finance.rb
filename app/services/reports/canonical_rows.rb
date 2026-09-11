# frozen_string_literal: true

module Reports
  class CanonicalRows
    attr_reader :context, :query_state, :cash_relation, :card_relation

    def initialize(context:, query_state:, cash_relation: context.cash_installments, card_relation: context.card_installments)
      @context = context
      @query_state = query_state
      @cash_relation = cash_relation
      @card_relation = card_relation
    end

    def call
      sort_rows(cash_rows + card_rows)
    end

    private

    def cash_rows
      return [] if cash_relation.nil?

      rows_for(
        query_state.apply(cash_relation).includes(cash_transaction: %i[categories entities]),
        transaction_method: :cash_transaction
      )
    end

    def card_rows
      return [] if card_relation.nil?

      rows_for(
        query_state.apply(card_relation).includes(card_transaction: %i[categories entities]),
        transaction_method: :card_transaction
      )
    end

    def rows_for(relation, transaction_method:)
      relation.map do |installment|
        transaction = installment.public_send(transaction_method)
        MovementRow.new(
          installment:,
          transaction:,
          occurred_on: query_state.occurred_on(installment),
          period_key: query_state.period_key(installment),
          movement_family: classifier.call(transaction)
        )
      end
    end

    def classifier
      @classifier ||= MovementClassifier.new
    end

    def sort_rows(rows)
      rows.sort_by do |row|
        value = case query_state.sort
                when "date_desc" then [ -row.occurred_on.jd, row.installment_type, row.installment_id ]
                when "amount_asc" then [ row.amount_cents, row.occurred_on, row.installment_type, row.installment_id ]
                when "amount_desc" then [ -row.amount_cents, row.occurred_on, row.installment_type, row.installment_id ]
                else [ row.occurred_on, row.installment_type, row.installment_id ]
                end
        value
      end
    end
  end
end
