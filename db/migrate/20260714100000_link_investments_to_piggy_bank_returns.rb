# frozen_string_literal: true

class LinkInvestmentsToPiggyBankReturns < ActiveRecord::Migration[8.1]
  def change
    add_reference :investments,
                  :piggy_bank_return_cash_transaction,
                  foreign_key: { to_table: :cash_transactions },
                  index: { name: "index_investments_on_piggy_bank_return_id" }
  end
end
