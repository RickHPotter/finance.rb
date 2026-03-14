# frozen_string_literal: true

class UserCardsController < ApplicationController
  include TabsConcern
  include ContextHelper

  before_action :set_user_card, only: %i[edit update destroy reference_date]
  before_action :set_cards, :set_user_cards, :set_entities, :set_categories, only: %i[new create edit update]
  before_action :set_basic_tabs

  def index
    params[:include_inactive] ||= "false"
    conditions = { active: [ true, !JSON.parse(params[:include_inactive]) ] }

    @user_cards = Logic::UserCards.find_by(current_user, conditions)
    render Views::UserCards::Index.new(user_cards: @user_cards, mobile: @mobile)
  end

  def new
    @user_card = current_user.user_cards.new
    render Views::UserCards::New.new(current_user:, user_card: @user_card, cards: @cards)
  end

  def create
    @user_card = Logic::UserCards.create(user_card_params)

    handle_save
  end

  def edit
    render Views::UserCards::Edit.new(current_user:, user_card: @user_card, cards: @cards)
  end

  def update
    @user_card = Logic::UserCards.update(@user_card, user_card_params)

    handle_save
  end

  def destroy
    @user_card.destroy if @user_card.card_transactions.empty?

    respond_to(&:turbo_stream)
  end

  def handle_save
    if @user_card.valid? && @user_card.active?
      @card_transaction = Logic::CardTransactions.create_from(user_card: @user_card)
      set_tabs(active_menu: :card, active_sub_menu: @card_transaction.user_card.user_card_name || :search)
    end

    respond_to(&:turbo_stream)
  end

  def reference_date
    date = Date.new(params[:year].to_i, params[:month].to_i)
    reference = @user_card.references.find_by(year: params[:year].to_i, month: params[:month].to_i)
    reference ||= @user_card.find_or_create_reference_for(date)

    render json: { reference_date: reference.reference_date }
  end

  private

  def set_basic_tabs
    set_tabs(active_menu: :basic, active_sub_menu: :user_card)
  end

  def set_user_card
    @user_card = current_user.user_cards.find(params[:id] || params[:user_card_id])
  end

  def user_card_params
    ret_params = params.require(:user_card)
    if ret_params[:current_closing_date].present? && ret_params[:current_due_date].present?
      ret_params[:current_closing_date] = ret_params[:current_closing_date].to_date
      ret_params[:current_due_date] = ret_params[:current_due_date].to_date

      ret_params[:due_date_day] = ret_params[:current_due_date].day
      ret_params[:days_until_due_date] = ret_params[:current_due_date] - ret_params[:current_closing_date]
    end

    ret_params.permit(
      :user_card_name, :due_date_day, :days_until_due_date, :min_spend, :credit_limit, :active, :user_id, :card_id,
      :current_closing_date, :current_due_date
    )
  end
end
