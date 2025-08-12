# frozen_string_literal: true

class EntitiesController < ApplicationController
  include TabsConcern
  include ContextHelper

  before_action :set_entity, only: %i[edit update destroy]
  before_action :set_user_cards, :set_entities, :set_categories, only: %i[new create edit update]

  def index
    params[:include_inactive] ||= "false"
    conditions = { active: [ true, !JSON.parse(params[:include_inactive]) ] }

    @entities = current_user.entities.where(conditions).order(entity_name: :asc)

    respond_to do |format|
      format.html

      format.turbo_stream do
        set_tabs(active_menu: :basic, active_sub_menu: :entity)
      end
    end
  end

  def show; end

  def new
    @entity = current_user.entities.new
  end

  def create
    index
    @entity = Logic::Entities.create(entity_params)

    if @entity.active?
      @card_transaction = Logic::CardTransactions.create_from(entity: @entity) if @entity.valid?

      if @card_transaction
        set_user_cards
        set_entities
        set_tabs(active_menu: :card, active_sub_menu: @card_transaction.user_card.user_card_name)
      end
    end

    respond_to(&:turbo_stream)
  end

  def edit; end

  def update
    index
    @entity = Logic::Entities.update(@entity, entity_params)

    if @entity.active?
      @card_transaction = Logic::CardTransactions.create_from(entity: @entity) if @entity.valid?

      if @card_transaction
        set_user_cards
        set_entities
        set_tabs(active_menu: :card, active_sub_menu: @card_transaction.user_card.user_card_name)
      end
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
    @entity = current_user.entities.find(params[:id])
  end

  # Only allow a list of trusted parameters through.
  def entity_params
    params.require(:entity).permit(:entity_name, :active, :avatar_name, :user_id)
  end
end
