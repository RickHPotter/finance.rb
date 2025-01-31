# frozen_string_literal: true

class CategoriesController < ApplicationController
  include TabsConcern

  before_action :set_user, only: %i[index new create edit update destroy]
  before_action :set_categories, only: %i[new create edit update]

  def index
    params[:include_inactive] ||= "false"
    conditions = { active: [ true, !JSON.parse(params[:include_inactive]) ] }
    @categories = current_user.categories.where(conditions)
  end

  def show; end

  def new
    @category = Category.new
  end

  def create
    @category = Category.new(card_params)
  end

  def edit; end

  def update; end

  def destroy
    @category.destroy if @category.card_transactions.empty?
    index

    respond_to(&:turbo_stream)
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_category
    @category = Category.find(params[:id])
  end

  # Only allow a list of trusted parameters through.
  def category_params
    params.require(:category).permit(:category_name, :active)
  end
end
