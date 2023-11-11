# frozen_string_literal: true

# Controller for CardTransaction
class CardTransactionsController < ApplicationController
  before_action :set_card_transaction, only: %i[show edit update destroy]

  def index
    @card_transactions = CardTransaction.all
  end

  def show; end

  def new
    @card_transaction = CardTransaction.new
  end

  def edit; end

  def create
    @card_transaction = CardTransaction.new(card_transaction_params)

    respond_to do |format|
      if @card_transaction.save
        format.html { redirect_to card_transactions_path }
      else
        format.html { render card_transactions_path, status: :unprocessable_entity }
      end
      format.turbo_stream
    end
  end

  def update
    respond_to do |format|
      if @card_transaction.update(card_transaction_params)
        format.html { redirect_to card_transactions_path, notice: 'Card Transaction was successfully updated.' }
      else
        format.html { render card_transactions_path, status: :unprocessable_entity }
      end
      format.turbo_stream
    end
  end

  def destroy
    @card_transaction.destroy
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to card_transactions_url, notice: 'Card Transaction was successfully destroyed.' }
    end
  end

  def clear_message
    respond_to(&:turbo_stream)
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_card_transaction
    @card_transaction = CardTransaction.find(params[:id])
  end

  # Only allow a list of trusted parameters through.
  def card_transaction_params
    params.require(:card_transaction).permit(
      :date, :card_id, :description, :comment, :category_id, :category2_id, :entity_id,
      :price, :month, :year, :installments, :installments_number
    )
  end
end

# TODO: StartingPrice has to be Price at create
