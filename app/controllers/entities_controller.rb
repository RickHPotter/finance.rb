# frozen_string_literal: true

class EntitiesController < ApplicationController
  include TabsConcern

  before_action :set_user, only: %i[index new create edit update destroy]
  before_action :set_entity, only: %i[edit update destroy]
  before_action :set_user_cards, :set_entities, :set_categories, only: %i[new create edit update]

  def index
    params[:include_inactive] ||= "false"
    conditions = { active: [ true, !JSON.parse(params[:include_inactive]) ] }

    @entities = Logic::Entities.find_by(current_user, conditions)
  end

  def show; end

  def new
    @entity = Entity.new
  end

  def create
    @entity = Logic::Entities.create(entity_params)
    @card_transaction = Logic::CardTransactions.create_from(entity: @entity) if @entity.valid?

    if @card_transaction
      set_user_cards
      set_entities
      set_tabs(active_menu: :basic, active_sub_menu: :card_transaction)
    end

    respond_to(&:turbo_stream)
  end

  def edit; end

  def update
    @entity = Logic::Entities.update(@entity, entity_params)
    @card_transaction = Logic::CardTransactions.create_from(entity: @entity) if @entity.valid?

    if @card_transaction
      set_user_cards
      set_entities
      set_tabs(active_menu: :basic, active_sub_menu: :card_transaction) if @entity.active?
    end

    respond_to(&:turbo_stream)
  end

  def destroy
    @entity.destroy if @entity.card_transactions.empty? && @entity.cash_transactions.empty?
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
    params.require(:entity).permit(:entity_name, :active, :user_id)
  end
end
