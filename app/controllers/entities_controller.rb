# frozen_string_literal: true

class EntitiesController < ApplicationController
  include TabsConcern
  include ContextHelper

  before_action :set_entity, only: %i[show edit update destroy]
  before_action :set_user_cards, :set_entities, :set_categories, only: %i[new create edit update]
  before_action :set_basic_tabs

  def index
    build_index_context
    @entities = entities_scope
    render Views::Entities::Index.new(entities: @entities, index_context: @index_context, mobile: @mobile)
  end

  def new
    @entity = current_user.entities.new
    render Views::Entities::New.new(current_user:, entity: @entity)
  end

  def create
    @entity = Logic::Entities.create(entity_params)

    handle_save
  end

  def show
    render Views::Entities::Show.new(entity: @entity)
  end

  def edit
    render Views::Entities::Edit.new(current_user:, entity: @entity)
  end

  def update
    @entity = Logic::Entities.update(@entity, entity_params)

    handle_save
  end

  def destroy
    @entity.destroy if destroyable_entity?

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

  def build_index_context
    @index_context = {
      search_term: search_params[:search_term],
      status: Array(filter_params[:status]).compact_blank
    }
  end

  def entities_scope
    build_index_context if @index_context.blank?

    scope = current_user.entities
    scope = scope.where(active: status_values) if @index_context[:status].present?

    if @index_context[:search_term].present?
      search_term = "%#{@index_context[:search_term].strip}%"
      scope = scope.where("entity_name ILIKE ?", search_term)
    end

    scope.order(active: :desc, entity_name: :asc)
  end

  def status_values
    @index_context[:status].filter_map do |status|
      case status
      when "active" then true
      when "inactive" then false
      end
    end.uniq
  end

  def set_basic_tabs
    set_tabs(active_menu: :data, active_sub_menu: :entity)
  end

  def set_entity
    @entity = current_user.entities.find(params[:id])
  end

  def entity_params
    params.require(:entity).permit(:entity_name, :active, :avatar_name, :user_id)
  end

  def destroyable_entity?
    !@entity.built_in? && @entity.card_transactions.empty? && @entity.cash_transactions.empty?
  end

  def search_params
    params.permit(:search_term)
  end

  def filter_params
    return {} if params[:entity].blank?

    params.require(:entity).permit(status: [])
  end
end
