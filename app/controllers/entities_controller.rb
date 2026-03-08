# frozen_string_literal: true

class EntitiesController < ApplicationController
  include TabsConcern
  include ContextHelper

  before_action :set_entity, only: %i[edit update destroy]
  before_action :set_user_cards, :set_entities, :set_categories, only: %i[new create edit update]
  before_action :set_basic_tabs

  def index
    params[:include_inactive] ||= "false"
    conditions = { active: [ true, !JSON.parse(params[:include_inactive]) ] }

    @entities = current_user.entities.where(conditions).order(entity_name: :asc)
    render Views::Entities::Index.new(entities: @entities, mobile: @mobile)
  end

  def new
    @entity = current_user.entities.new
    render Views::Entities::New.new(current_user:, entity: @entity)
  end

  def create
    @entity = Logic::Entities.create(entity_params)

    handle_save
  end

  def edit
    render Views::Entities::Edit.new(current_user:, entity: @entity)
  end

  def update
    @entity = Logic::Entities.update(@entity, entity_params)

    handle_save
  end

  def destroy
    @entity.destroy if @entity.card_transactions.empty? && @entity.cash_transactions.empty?

    respond_to(&:turbo_stream)
  end

  def handle_save
    if @entity.valid? && @entity.active?
      @card_transaction = Logic::CardTransactions.create_from(entity: @entity)
      set_tabs(active_menu: :card, active_sub_menu: @card_transaction.user_card.user_card_name || :search)
    end

    respond_to(&:turbo_stream)
  end

  private

  def set_basic_tabs
    set_tabs(active_menu: :basic, active_sub_menu: :entity)
  end

  def set_entity
    @entity = current_user.entities.find(params[:id])
  end

  def entity_params
    params.require(:entity).permit(:entity_name, :active, :avatar_name, :user_id)
  end
end
