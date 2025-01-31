# frozen_string_literal: true

class EntitiesController < ApplicationController
  include TabsConcern

  before_action :set_user, only: %i[index new create edit update destroy]
  before_action :set_entities, only: %i[new create edit update]

  def index
    params[:include_inactive] ||= "false"
    conditions = { active: [ true, !JSON.parse(params[:include_inactive]) ] }
    @entities = current_user.entities.where(conditions)
  end

  def show; end

  def new
    @entity = Entity.new
  end

  def create
    @entity = Entity.new(card_params)
  end

  def edit; end

  def update; end

  def destroy
    @entity.destroy if @entity.card_transactions.empty?
    index

    respond_to(&:turbo_stream)
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_entity
    @entity = Entity.find(params[:id])
  end

  # Only allow a list of trusted parameters through.
  def entity_params
    params.require(:entity).permit(:entity_name, :active)
  end
end
