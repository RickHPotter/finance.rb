# frozen_string_literal: true

class UserCardsController < ApplicationController
  include TabsConcern
  include ContextHelper

  before_action :set_user_card, only: %i[show edit update destroy reference_date]
  before_action :set_cards, :set_user_cards, :set_entities, :set_categories, only: %i[new create edit update]
  before_action :set_basic_tabs

  def index
    build_index_context
    @user_cards = user_cards_scope
    @index_context[:return_to] = user_card_navigation_return_param(request.fullpath)
    render_top_level Views::UserCards::Index.new(user_cards: @user_cards, index_context: @index_context, mobile: @mobile)
  end

  def new
    @user_card = current_user.user_cards.new
    set_return_to
    render_top_level Views::UserCards::New.new(current_user:, user_card: @user_card, cards: @cards, return_to: @return_to)
  end

  def create
    @user_card = Logic::UserCards.create(user_card_params)

    handle_save
  end

  def show
    set_return_to
    render_top_level Views::UserCards::Show.new(user_card: @user_card, return_to: @return_to)
  end

  def edit
    set_return_to
    render_top_level Views::UserCards::Edit.new(current_user:, user_card: @user_card, cards: @cards, return_to: @return_to)
  end

  def update
    @user_card = Logic::UserCards.update(@user_card, user_card_params)

    handle_save
  end

  def destroy
    set_return_to
    @user_card.destroy if @user_card.card_transactions.empty?

    if @user_card.destroyed?
      redirect_to @return_to, notice: notification_model(:destroyed, UserCard), status: :see_other
    else
      redirect_to @return_to, alert: user_card_destroy_failure_notification, status: :see_other
    end
  end

  def handle_save
    set_return_to
    return render_user_card_failure unless @user_card.valid?

    if @user_card.active?
      @card_transaction = Logic::CardTransactions.create_from(user_card: @user_card)
      set_tabs(active_menu: :card, active_sub_menu: @card_transaction.user_card.user_card_name || :search)
    end

    redirect_to user_card_save_destination,
                notice: notification_model(action_name == "create" ? :created : :updated, UserCard),
                status: :see_other
  end

  def reference_date
    date = Date.new(params[:year].to_i, params[:month].to_i)
    reference = @user_card.references.find_by(context: current_context, year: params[:year].to_i, month: params[:month].to_i)
    reference ||= @user_card.find_or_create_reference_for(date, context: current_context)

    render json: { reference_date: reference.reference_date }
  end

  private

  def render_top_level(view)
    respond_to { |format| format.html { render view } }
  end

  def render_user_card_failure
    view =
      if action_name == "create"
        Views::UserCards::New.new(current_user:, user_card: @user_card, cards: @cards, return_to: @return_to)
      else
        Views::UserCards::Edit.new(current_user:, user_card: @user_card, cards: @cards, return_to: @return_to)
      end

    respond_to do |format|
      format.html { render view, status: :unprocessable_content }
      format.turbo_stream { render action_name, status: :unprocessable_content }
    end
  end

  def user_card_save_destination
    return @return_to if @card_transaction.blank?

    new_card_transaction_path(user_card_id: @user_card.id)
  end

  def set_return_to
    @return_to = dashboard_navigation_destination(params[:return_to]) || user_card_navigation_destination(params[:return_to])
  end

  def user_card_navigation_destination(raw)
    Navigation::UserCards.new(raw:, fallback: user_cards_path, current_user:).destination
  end

  def user_card_navigation_return_param(raw)
    destination = user_card_navigation_destination(raw)
    destination unless destination == user_cards_path
  end

  def user_card_destroy_failure_notification
    @user_card.errors.full_messages.to_sentence.presence || notification_model(:not_destroyed_because_has_transactions, UserCard)
  end

  def build_index_context
    @index_context = {
      search_term: search_params[:search_term],
      status: Array(filter_params[:status]).compact_blank
    }
  end

  def user_cards_scope
    build_index_context if @index_context.blank?

    scope = current_user.user_cards.includes(:card).left_outer_joins(:card)
    scope = scope.where(active: status_values) if @index_context[:status].present?

    if @index_context[:search_term].present?
      search_term = "%#{@index_context[:search_term].strip}%"
      scope = scope.where("user_card_name ILIKE :search OR cards.card_name ILIKE :search", search: search_term)
    end

    scope.distinct.order(active: :desc, user_card_name: :asc)
  end

  def status_values
    @index_context[:status].filter_map do |status|
      case status
      when "active" then true
      when "inactive" then false
      end
    end.uniq
  end

  def set_basic_tabs
    set_tabs(active_menu: :data, active_sub_menu: :user_card)
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

  def search_params
    params.permit(:search_term)
  end

  def filter_params
    return {} if params[:user_card].blank?

    params.require(:user_card).permit(status: [])
  end
end
