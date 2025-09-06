# frozen_string_literal: true

module Logic
  module Manipulation
    class CashInstallment
      attr_reader :cash_installment, :cash_transaction

      def initialize(cash_installment)
        @cash_installment = cash_installment
        @cash_transaction = @cash_installment.cash_transaction
      end

      def split_installment(date, price)
        new_cash_installment = create_new_installment(date, price)
        update_subsequent_installments(new_cash_installment)

        @cash_transaction.cash_installments.update_all(cash_installments_count: @cash_transaction.cash_installments.count)
      end

      private

      def create_new_installment(date, price)
        cash_transaction.cash_installments.create!(
          number: cash_installment.number + 1,
          date:,
          month: date.month,
          year: date.year,
          price:
        )
      end

      def update_subsequent_installments(new_cash_installment)
        cash_installments       = cash_transaction.cash_installments
        subsequent_installments = cash_installments.where(number: [ new_cash_installment.number.. ]).where.not(id: new_cash_installment.id)

        subsequent_installments.each do |ci|
          ci.update_columns(number: ci.number + 1)
        end
      end
    end
  end
end
