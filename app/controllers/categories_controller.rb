# frozen_string_literal: true

class CategoriesController < ApplicationController
  include TabsConcern
  include ContextHelper

  before_action :set_category, only: %i[edit update destroy]
  before_action :set_user_cards, :set_entities, :set_categories, only: %i[new create edit update]

  def index
    params[:include_inactive] ||= "false"
    conditions = { active: [ true, !JSON.parse(params[:include_inactive]) ] }

    @categories = current_user.categories.where(conditions).order(category_name: :asc)

    respond_to do |format|
      format.html

      format.turbo_stream do
        set_tabs(active_menu: :basic, active_sub_menu: :category)
      end
    end
  end

  def show; end

  def new
    @category = current_user.categories.new
  end

  def create
    index
    @category = Logic::Categories.create(category_params)

    if @category.active? && !@category.built_in?
      @card_transaction = Logic::CardTransactions.create_from(category: @category) if @category.valid?

      if @card_transaction
        set_user_cards
        set_categories
        set_tabs(active_menu: :card, active_sub_menu: @card_transaction.user_card.user_card_name)
      end
    end

    respond_to(&:turbo_stream)
  end

  def edit; end

  def update
    index
    @category = Logic::Categories.update(@category, category_params)

    if @category.active? && !@category.built_in?
      @card_transaction = Logic::CardTransactions.create_from(category: @category) if @category.valid?

      if @card_transaction
        set_user_cards
        set_categories
        set_tabs(active_menu: :card, active_sub_menu: @card_transaction.user_card.user_card_name)
      end
    end

    respond_to(&:turbo_stream)
  end

  def destroy
    @category.destroy if @category.card_transactions.empty? && @category.cash_transactions.empty? && @category.investments.empty?
    index

    respond_to(&:turbo_stream)
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_category
    @category = current_user.categories.find(params[:id])
  end

  # Only allow a list of trusted parameters through.
  def category_params
    params.require(:category).permit(:category_name, :colour, :active, :user_id)
  end
end
