# frozen_string_literal: true

class CategoriesController < ApplicationController
  include TabsConcern
  include ContextHelper

  before_action :set_category, only: %i[edit update destroy]
  before_action :set_user_cards, :set_entities, :set_categories, only: %i[new create edit update]
  before_action :set_basic_tabs

  def index
    params[:include_inactive] ||= "false"
    conditions = { active: [ true, !JSON.parse(params[:include_inactive]) ] }

    @categories = current_user.categories.where(conditions).order(category_name: :asc)
    render Views::Categories::Index.new(categories: @categories, mobile: @mobile)
  end

  def new
    @category = current_user.categories.new
    render Views::Categories::New.new(current_user:, category: @category)
  end

  def create
    @category = Logic::Categories.create(category_params)

    handle_save
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
    end

    respond_to(&:turbo_stream)
  end

  private

  def set_basic_tabs
    set_tabs(active_menu: :basic, active_sub_menu: :category)
  end

  def set_category
    @category = current_user.categories.find(params[:id])
  end

  def category_params
    params.require(:category).permit(:category_name, :colour, :active, :user_id)
  end
end
