# frozen_string_literal: true

class UserCardsController < ApplicationController
  include TabsConcern

  before_action :set_user, only: %i[index new create edit update destroy]
  before_action :set_user_card, only: %i[edit update destroy]
  before_action :set_cards, :set_user_cards, :set_entities, :set_categories, only: %i[new create edit update]

  def index
    params[:include_inactive] ||= "false"
    conditions = { active: [ true, !JSON.parse(params[:include_inactive]) ] }

    @user_cards = Logic::UserCards.find_by(current_user, conditions)
  end

  def new
    @user_card = UserCard.new

    respond_to do |format|
      format.html
      format.turbo_stream do
        set_tabs(active_menu: :new, active_sub_menu: :user_card) if params[:no_user_card]
      end
    end
  end

  def create
    @user_card = Logic::UserCards.create(user_card_params)
    @card_transaction = Logic::CardTransactions.create_from(user_card: @user_card) if @user_card.valid?

    if @card_transaction
      set_user_cards
      set_tabs(active_menu: :new, active_sub_menu: :card_transaction)
    end

    respond_to(&:turbo_stream)
  end

  def edit; end

  def update
    @user_card = Logic::UserCards.update(@user_card, user_card_params)
    @card_transaction = Logic::CardTransactions.create_from(user_card: @user_card) if @user_card.valid?

    if @card_transaction
      set_user_cards
      set_tabs(active_menu: :new, active_sub_menu: :card_transaction) if @user_card.active?
    end

    respond_to(&:turbo_stream)
  end

  def destroy
    @user_card.destroy if @user_card.card_transactions.empty?
    index

    respond_to(&:turbo_stream)
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_user_card
    @user_card = UserCard.find(params[:id])
  end

  # Only allow a list of trusted parameters through.
  def user_card_params
    params.require(:user_card).permit(
      :user_card_name, :current_closing_date, :current_due_date, :min_spend, :credit_limit, :active, :user_id, :card_id
    )
  end
end
