# frozen_string_literal: true

# Controller for CardTransaction
class CardTransactionsController < ApplicationController
  before_action :set_card_transaction, only: %i[show update destroy]
  before_action :set_user, :set_user_cards, :set_entities, :set_categories, only: %i[new create edit update]

  def index
    @card_transactions = CardTransaction.all.eager_load(
      :user_card, :installments, category_transactions: :category, entity_transactions: :entity
    ).order(date: :desc)
  end

  def show; end

  def new
    @card_transaction = CardTransaction.new
  end

  def edit
    @card_transaction =
      CardTransaction
      .eager_load(:installments, category_transactions: :category, entity_transactions: :entity)
      .find(params[:id])
  end

  def create
    @card_transaction = CardTransaction.new(card_transaction_params)

    if @card_transaction.save
      flash[:notice] = "Card Transaction was successfully created."
    else
      flash[:alert] = @card_transaction.errors.full_messages
    end

    respond_to do |format|
      format.turbo_stream
      format.json { render json: @card_transaction }
    end
  end

  def update
    if @card_transaction.update(card_transaction_params)
      flash[:notice] = "Card Transaction was successfully updated."
    else
      flash[:alert] = @card_transaction.errors.full_messages
    end

    respond_to(&:turbo_stream)
  end

  def destroy
    if @card_transaction.destroy
      flash[:notice] = "Card Transaction was successfully destroyed."
    else
      flash[:alert] = @card_transaction.errors.full_messages
    end

    respond_to(&:turbo_stream)
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
    @user_cards = @user.user_cards.order(:user_card_name).pluck(:user_card_name, :id)
  end

  def set_categories
    @categories = @user.custom_categories.order(:category_name).pluck(:category_name, :id)
  end

  def set_entities
    @entities = @user.entities.order(:entity_name).pluck(:entity_name, :id)
  end

  # Only allow a list of trusted parameters through.
  def card_transaction_params
    params.require(:card_transaction).permit(
      :ct_description, :ct_comment, :date, :month, :year, :price, :installments_count,
      :user_id, :user_card_id,
      installments_attributes: %i[id price number paid],
      category_transactions_attributes: %i[id category_id],
      entity_transactions_attributes: [
        :id, :entity_id, :is_payer, :price,
        { exchanges_attributes: %i[id exchange_type price] }
      ]
    )
  end
end
