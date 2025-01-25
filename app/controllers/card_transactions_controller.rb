# frozen_string_literal: true

# Controller for CardTransaction
class CardTransactionsController < ApplicationController
  include TabsConcern

  before_action :set_tabs
  before_action :set_card_transaction, only: %i[show update destroy]
  before_action :set_user, :set_cards, :set_user_cards, :set_entities, :set_categories, only: %i[new create edit update]

  def index
    user_card_id = params[:user_card_id]
    redirect_to new_card_transaction_path and return if user_card_id.blank?

    @user_card = UserCard.find_by(id: user_card_id)
    redirect_to new_card_transaction_path and return if @user_card.blank?

    max_date = @user_card.card_installments.maximum("MAKE_DATE(installments.year, installments.month, 1)")
    l_date, r_date = RefMonthYear.get_span(Date.current, max_date, 6)

    @card_installments = @user_card.card_installments
                                   .includes(card_transaction: %i[categories entities])
                                   .where("MAKE_DATE(installments.year, installments.month, 1) BETWEEN ? AND ?", l_date, r_date)
                                   .order("installments.date DESC")
                                   .group_by { |t| Date.new(t.year, t.month) }
                                   .sort
                                   .reverse
  end

  def show; end

  def new
    @card_transaction = CardTransaction.new
  end

  def edit
    @card_transaction = CardTransaction.includes(:installments, category_transactions: :category, entity_transactions: :entity).find(params[:id])
  end

  def create
    @card_transaction = CardTransaction.new(card_transaction_params)
    @card_transaction.build_month_year

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
