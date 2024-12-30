# frozen_string_literal: true

# Controller for Transaction
class TransactionsController < ApplicationController
  def index
    user_card_id = current_user.user_cards.first.id
    @transactions = CashTransaction.where(cash_transaction_type: "Installment", user_card_id:).order(:date)
  end
end
