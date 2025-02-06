# frozen_string_literal: true

# Controller for CardTransaction
class CardTransactionsController < ApplicationController
  include TabsConcern

  before_action :set_tabs
  before_action :set_card_transaction, only: %i[edit update destroy]
  before_action :set_user, :set_cards, :set_user_cards, :set_entities, :set_categories, only: %i[new create edit update]

  def index
    @user_card ||= current_user.user_cards.find_by(id: params[:user_card_id])                  if params[:user_card_id]
    @user_card ||= current_user.user_cards.find_by(id: card_transaction_params[:user_card_id]) if params[:card_transaction]
    @card_installments = Logic::CardInstallments.find_by_span(@user_card, 6) if @user_card
    @card_installments ||= Logic::CardInstallments.find_by_params(current_user, params)

    respond_to do |format|
      format.html
      format.turbo_stream do
        set_tabs(active_menu: :card, active_sub_menu: @user_card&.user_card_name || :search)
      end
    end
  end

  def show; end

  def new
    @card_transaction = CardTransaction.new(user_card: current_user.user_cards.active.order(:user_card_name).first)
    @card_transaction.build_month_year

    respond_to do |format|
      format.html
      format.turbo_stream do
        set_tabs(active_menu: :new, active_sub_menu: :card_transaction)
      end
    end
  end

  def edit
    @card_transaction = CardTransaction.includes(:card_installments).find(params[:id])
  end

  def create
    @card_transaction = CardTransaction.new(card_transaction_params)
    @card_transaction.build_month_year if @card_transaction.user_card_id

    case params[:commit]
    when "Submit", nil
      if @card_transaction.save
        @user_card = @card_transaction.user_card
        index
        set_tabs(active_menu: :card, active_sub_menu: @card_transaction.user_card.user_card_name)
      end

      respond_to(&:turbo_stream)
    when "Update"
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.update(@card_transaction, partial: "card_transactions/form", locals: { card_transaction: @card_transaction })
        end
      end
    end
  end

  def update
    @card_transaction.assign_attributes(card_transaction_params)
    @card_transaction.build_month_year if @card_transaction.user_card_id

    case params[:commit]
    when "Submit", nil
      if @card_transaction.save
        @user_card = @card_transaction.user_card
        index
        set_tabs(active_menu: :card, active_sub_menu: @card_transaction.user_card.user_card_name)
      end

      respond_to(&:turbo_stream)
    when "Update"
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.update(@card_transaction, partial: "card_transactions/form", locals: { card_transaction: @card_transaction })
        end
      end
    end
  end

  def destroy
    @user_card = @card_transaction.user_card
    @card_transaction.destroy
    index

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
