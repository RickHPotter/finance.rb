# frozen_string_literal: true

class CardsController < ApplicationController
  before_action :set_card, only: %i[show edit update destroy]
  before_action :set_user, only: %i[new create edit update]

  def index; end
  def show; end

  def new
    @card = Card.new
  end

  def create
    @card = Card.new(card_params)
  end

  def edit; end
  def update; end
  def destroy; end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_card
    @card = Card.find(params[:id])
  end

  # Only allow a list of trusted parameters through.
  def card_params
    params.require(:card).permit(:card_name)
  end
end
