# frozen_string_literal: true

# Controller for CardTransaction
class CardTransactionsController < ApplicationController
  include TabsConcern

  before_action :set_tabs
  before_action :set_card_transaction, only: %i[show update destroy]
  before_action :set_user, :set_cards, :set_user_cards, :set_entities, :set_categories, only: %i[new create edit update]

  def index
    @user_card = current_user.user_cards.find_by(id: params[:user_card_id])
    @card_installments = Logic::CardInstallments.find_by_span(@user_card, 6) if @user_card
    @card_installments ||= Logic::CardInstallments.find_by_params(current_user, params)

    respond_to do |format|
      format.html
      format.turbo_stream do
        set_tabs(active_menu: :card, active_sub_menu: @user_card&.user_card_name&.to_sym || "")
      end
    end
  end

  def show; end

  def new
    @card_transaction = CardTransaction.new(user_card: current_user.user_cards.active.order(:user_card_name).first)
    @card_transaction.build_month_year
  end

  def edit
    @card_transaction = CardTransaction.includes(:installments, category_transactions: :category, entity_transactions: :entity).find(params[:id])
  end

  def create
    @card_transaction = CardTransaction.new(card_transaction_params)
    @card_transaction.build_month_year if @card_transaction.user_card_id

    if params[:commit] == "Update"
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.update(@card_transaction, partial: "card_transactions/form", locals: { card_transaction: @card_transaction })
        end
      end
    else
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

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_card_transaction
    @card_transaction = CardTransaction.find(params[:id])
  end

  # Only allow a list of trusted parameters through.
  def card_transaction_params
    params.require(:card_transaction).permit(
      %i[id description comment date month year price user_id user_card_id],
      category_transactions_attributes: %i[id category_id],
      card_installments_attributes: %i[id number date month year price],
      entity_transactions_attributes: [
        :id, :entity_id, :is_payer, :price,
        { exchanges_attributes: %i[id exchange_type price] }
      ]
    )
  end
end
