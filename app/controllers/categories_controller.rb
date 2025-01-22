# frozen_string_literal: true

class CategoriesController < ApplicationController
  before_action :set_card, only: %i[show edit update destroy]
  before_action :set_user, only: %i[new create edit update]

  def index; end
  def show; end

  def new
    @category = Category.new
  end

  def create
    @category = Category.new(card_params)
  end

  def edit; end
  def update; end
  def destroy; end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_category
    @category = Category.find(params[:id])
  end

  # Only allow a list of trusted parameters through.
  def category_params
    params.require(:category).permit(:card_name)
  end
end
