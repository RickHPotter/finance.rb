# frozen_string_literal: true

# Controller for CardTransaction
class CardTransactionsController < ApplicationController
  before_action :set_card_transaction, only: %i[show edit update destroy]
  before_action :set_user, :set_user_cards, :set_entities, :set_categories, only: %i[new create edit update]

  def index
    @card_transactions = CardTransaction.all.eager_load(
      # :user_card, :installments, category_transactions: :category, entity_transactions: :entity
      :user_card, :installments
    )
  end

  def show; end

  def new
    @card_transaction = CardTransaction.new
  end

  def edit; end

  def create
    @card_transaction = CardTransaction.new(card_transaction_params)

    if @card_transaction.save
      flash[:notice] = 'Card Transaction was successfully created.'
    else
      flash[:alert] = @card_transaction.errors.full_messages
    end

    respond_to(&:turbo_stream)
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

  def set_user
    @user = current_user if user_signed_in?
  end

  def set_user_cards
    @user_cards = @user.user_cards.order(:user_card_name).pluck(:id, :user_card_name)
  end

  def set_entities
    @entities = @user.entities.order(:entity_name).pluck(:id, :entity_name)
  end

  def set_categories
    @categories = @user.categories.order(:category_name).pluck(:id, :category_name)
  end

  # Only allow a list of trusted parameters through.
  def card_transaction_params
    params.require(:card_transaction).permit(
      :ct_description, :ct_comment, :date, :month, :year, :price, :installments_count,
      :user_id, :user_card_id,
      installments_attributes: %i[price number paid],
      entity_transaction_attributes: [
        :is_payer, :price,
        { exchange_attributes: %i[exchange_type price] }
      ]
    )
  end
end
