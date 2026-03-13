# frozen_string_literal: true

class BackfillInvestmentTypeForInvestmentCashTransactions < ActiveRecord::Migration[7.1]
  Investment.class_eval do
    def public_desc
      cash_transaction_description
    end
  end

  CashTransaction.class_eval do
    def investment_description
      return if investments.empty?

      investments.first.public_desc
    end
  end

  def up
    default_investment_type = InvestmentType.find_by!(investment_type_code: "renda_fixa_liquidez_diaria")

    CashTransaction.where(cash_transaction_type: "Investment").includes(:investments).find_each do |cash_transaction|
      investment_type_ids = cash_transaction.investments.pluck(:investment_type_id).uniq
      next if investment_type_ids.size != 1

      investment_type_id = investment_type_ids.first || default_investment_type.id
      cash_transaction.update_columns(description: cash_transaction.investment_description, investment_type_id:)
    end
  end

  def down; end
end
