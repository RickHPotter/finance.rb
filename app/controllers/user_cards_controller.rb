# frozen_string_literal: true

class UserCardsController < ApplicationController
  before_action :set_user_card, only: %i[show edit update destroy]
  before_action :set_user, :set_cards, only: %i[index new create edit update]

  def index
    params[:include_inactive] ||= "false"
    conditions = { active: [ true, !JSON.parse(params[:include_inactive]) ] }
    @user_cards = @user.user_cards.includes(:card).where(conditions)
  end

  def show; end

  def new
    @user_card = UserCard.new
  end

  def create
    @user_card = UserCard.new(user_card_params)
  end

  def edit
    # @card_transaction = CardTransaction.includes(:installments, category_transactions: :category, entity_transactions: :entity).find(params[:id])
  end

  def update; end
  def destroy; end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_user_card
    @user_card = UserCard.find(params[:id])
  end

  # Only allow a list of trusted parameters through.
  def user_card_params
    params.require(:user_card).permit(:user_card_name, :days_until_due_date, :current_closing_date, :current_due_date, :min_spend,
                                      :credit_limit, :active, :user_id, :card_id)
  end
end
