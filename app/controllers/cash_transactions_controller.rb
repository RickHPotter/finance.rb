# frozen_string_literal: true

# Controller for CashTransaction
class CashTransactionsController < ApplicationController
  before_action :set_cash_transaction, only: %i[show update destroy]
  before_action :set_entities, :set_categories, only: %i[new create edit update]

  def index
    @cash_installments = Logic::CashInstallments.find_by_span(current_user, 6)
  end

  def show; end

  def edit; end

  def update; end

  def new
    @cash_transaction = CashTransaction.new
  end

  def create
    @cash_transaction = CashTransaction.new(card_transaction_params)
  end

  def destroy; end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_card_transaction
    @cash_transaction = CashTransaction.find(params[:id])
  end

  # Only allow a list of trusted parameters through.
  def card_transaction_params
    params.require(:card_transaction).permit(
      %i[id description comment date month year price user_id user_card_id],
      category_transactions_attributes: %i[id category_id],
      cash_installments_attributes: %i[id number date month year price],
      entity_transactions_attributes: [
        :id, :entity_id, :is_payer, :price,
        { exchanges_attributes: %i[id exchange_type price] }
      ]
    )
  end
end
