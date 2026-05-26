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
    render Views::Categories::Index.new(categories: @categories, index_context: @index_context, mobile: @mobile)
  end

  def new
    @category = current_user.categories.new
    render Views::Categories::New.new(current_user:, category: @category)
  end

  def create
    @category = Logic::Categories.create(category_params)

    handle_save
  end

  def show
    render Views::Categories::Show.new(category: @category)
  end

  def edit
    render Views::Categories::Edit.new(current_user:, category: @category)
  end

  def update
    @category = Logic::Categories.update(@category, category_params)

    handle_save
  end

  def destroy
    @category.destroy if @category.card_transactions.empty? && @category.cash_transactions.empty? && @category.investments.empty?

    respond_to(&:turbo_stream)
  end

  def handle_save
    if @category.valid? && @category.active? && !@category.built_in?
      @card_transaction = Logic::CardTransactions.create_from(category: @category)
      set_tabs(active_menu: :card, active_sub_menu: @card_transaction.user_card.user_card_name || :search)
    else
      build_index_context
      @categories = categories_scope
    end

    respond_to(&:turbo_stream)
  end

  private

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
    params.require(:category).permit(:category_name, :colour, :active, :user_id)
  end

  def search_params
    params.permit(:search_term)
  end

  def filter_params
    return {} if params[:category].blank?

    params.require(:category).permit(status: [])
  end
end
