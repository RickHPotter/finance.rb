# frozen_string_literal: true

class CategoriesController < ApplicationController
  include TabsConcern
  include ContextHelper

  before_action :set_category, only: %i[show edit update destroy]
  before_action :set_user_cards, :set_entities, :set_categories, only: %i[new create edit update]
  before_action :set_basic_tabs

  def index
    build_index_context
    @categories = categories_scope
    @index_context[:return_to] = category_navigation_return_param(request.fullpath)
    render_top_level Views::Categories::Index.new(categories: @categories, index_context: @index_context, mobile: @mobile)
  end

  def new
    @category = current_user.categories.new
    set_return_to
    render_top_level Views::Categories::New.new(current_user:, category: @category, return_to: @return_to)
  end

  def create
    @category = Logic::Categories.create(category_params)

    handle_save
  end

  def show
    set_return_to
    render_top_level Views::Categories::Show.new(category: @category, return_to: @return_to)
  end

  def edit
    set_return_to
    render_top_level Views::Categories::Edit.new(current_user:, category: @category, return_to: @return_to)
  end

  def update
    @category = Logic::Categories.update(@category, category_params)

    handle_save
  end

  def destroy
    set_return_to
    @category.destroy if destroyable_category?

    if @category.destroyed?
      redirect_to @return_to, notice: notification_model(:destroyeda, Category), status: :see_other
    else
      redirect_to @return_to, alert: category_destroy_failure_notification, status: :see_other
    end
  end

  def handle_save
    set_return_to
    return render_category_failure unless @category.valid?

    if @category.active? && !@category.built_in?
      @card_transaction = Logic::CardTransactions.create_from(category: @category)
      set_tabs(active_menu: :card, active_sub_menu: @card_transaction.user_card.user_card_name || :search) if @card_transaction.present?
    end

    redirect_to category_save_destination,
                notice: notification_model(action_name == "create" ? :createda : :updateda, Category),
                status: :see_other
  end

  private

  def render_top_level(view)
    respond_to { |format| format.html { render view } }
  end

  def render_category_failure
    view =
      if action_name == "create"
        Views::Categories::New.new(current_user:, category: @category, return_to: @return_to)
      else
        Views::Categories::Edit.new(current_user:, category: @category, return_to: @return_to)
      end

    respond_to do |format|
      format.html { render view, status: :unprocessable_content }
      format.turbo_stream { render action_name, status: :unprocessable_content }
    end
  end

  def category_save_destination
    return @return_to if @card_transaction.blank?

    new_card_transaction_path(
      user_card_id: @card_transaction.user_card_id,
      card_transaction: { category_id: @category.id }
    )
  end

  def set_return_to
    @return_to = category_navigation_destination(params[:return_to])
  end

  def category_navigation_destination(raw)
    Navigation::Categories.new(raw:, fallback: categories_path, current_user:).destination
  end

  def category_navigation_return_param(raw)
    destination = category_navigation_destination(raw)
    destination unless destination == categories_path
  end

  def build_index_context
    @index_context = {
      search_term: search_params[:search_term],
      status: Array(filter_params[:status]).compact_blank
    }
  end

  def categories_scope
    build_index_context if @index_context.blank?

    scope = current_user.categories
    scope = scope.where(active: status_values) if @index_context[:status].present?

    if @index_context[:search_term].present?
      search_term = "%#{@index_context[:search_term].strip}%"
      scope = scope.where("category_name ILIKE ?", search_term)
    end

    scope.order(active: :desc, category_name: :asc)
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
    set_tabs(active_menu: :data, active_sub_menu: :category)
  end

  def set_category
    @category = current_user.categories.find(params[:id])
  end

  def category_params
    params.require(:category).permit(:category_name, :colour, :text_colour_mode, :text_colour, :active, :user_id)
  end

  def destroyable_category?
    !@category.built_in? && @category.card_transactions.empty? && @category.cash_transactions.empty? && @category.investments.empty?
  end

  def category_destroy_failure_notification
    return notification_model(:not_destroyeda, Category) if @category.built_in?

    @category.errors.full_messages.to_sentence.presence || notification_model(:not_destroyed_because_has_transactionsa, Category)
  end

  def search_params
    params.permit(:search_term)
  end

  def filter_params
    return {} if params[:category].blank?

    params.require(:category).permit(status: [])
  end
end
