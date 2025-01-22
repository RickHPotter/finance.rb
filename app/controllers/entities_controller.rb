# frozen_string_literal: true

class EntitiesController < ApplicationController
  before_action :set_card, only: %i[show edit update destroy]
  before_action :set_user, only: %i[new create edit update]

  def index; end
  def show; end

  def new
    @entity = Entity.new
  end

  def create
    @entity = Entity.new(card_params)
  end

  def edit; end
  def update; end
  def destroy; end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_entity
    @entity = Entity.find(params[:id])
  end

  # Only allow a list of trusted parameters through.
  def entity_params
    params.require(:entity).permit(:card_name)
  end
end
