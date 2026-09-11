# frozen_string_literal: true

module Reports
  class MovementClassifier
    FAILED_CATEGORY_NAMES = [ "FAILED LEND/BORROW RETURN" ].freeze
    TRANSFER_CATEGORY_NAMES = [ "EXCHANGE", "EXCHANGE RETURN", "BORROW RETURN" ].freeze
    PIGGY_BANK_CATEGORY_NAMES = [ "PIGGY BANK", "PIGGY BANK RETURN" ].freeze

    def call(transaction)
      return :generated_card_payment if cash_type?(transaction, "CardInstallment")

      category_names = transaction.categories.map(&:category_name)
      return :failed_transfer if category_names.intersect?(FAILED_CATEGORY_NAMES)
      return :transfer if category_names.intersect?(TRANSFER_CATEGORY_NAMES)
      return :piggy_bank if cash_type?(transaction, "PiggyBank") || category_names.intersect?(PIGGY_BANK_CATEGORY_NAMES)
      return :generated_investment if cash_type?(transaction, "Investment")

      :ordinary
    end

    def ordinary?(transaction)
      call(transaction) == :ordinary
    end

    private

    def cash_type?(transaction, type)
      transaction.is_a?(CashTransaction) && transaction.cash_transaction_type == type
    end
  end
end
