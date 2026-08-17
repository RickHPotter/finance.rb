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
    @index_context[:return_to] = entity_navigation_return_param(request.fullpath)
    render_top_level Views::Entities::Index.new(entities: @entities, index_context: @index_context, mobile: @mobile)
  end

  def new
    @entity = current_user.entities.new
    set_return_to
    render_top_level Views::Entities::New.new(current_user:, entity: @entity, return_to: @return_to)
  end

  def create
    @entity = Logic::Entities.create(entity_params)

    handle_save
  end

  def show
    set_return_to
    render_top_level Views::Entities::Show.new(entity: @entity, return_to: @return_to)
  end

  def edit
    set_return_to
    render_top_level Views::Entities::Edit.new(current_user:, entity: @entity, return_to: @return_to)
  end

  def update
    @entity = Logic::Entities.update(@entity, entity_params)

    handle_save
  end

  def destroy
    set_return_to
    @entity.destroy if destroyable_entity?

    if @entity.destroyed?
      redirect_to @return_to, notice: notification_model(:destroyeda, Entity), status: :see_other
    else
      redirect_to @return_to, alert: entity_destroy_failure_notification, status: :see_other
    end
  end

  def handle_save
    set_return_to
    return render_entity_failure unless @entity.valid?

    if @entity.active?
      @card_transaction = Logic::CardTransactions.create_from(entity: @entity)
      set_tabs(active_menu: :card, active_sub_menu: @card_transaction.user_card.user_card_name || :search) if @card_transaction.present?
    end

    redirect_to entity_save_destination,
                notice: notification_model(action_name == "create" ? :createda : :updateda, Entity),
                status: :see_other
  end

  private

  def render_top_level(view)
    respond_to { |format| format.html { render view } }
  end

  def render_entity_failure
    view =
      if action_name == "create"
        Views::Entities::New.new(current_user:, entity: @entity, return_to: @return_to)
      else
        Views::Entities::Edit.new(current_user:, entity: @entity, return_to: @return_to)
      end

    respond_to do |format|
      format.html { render view, status: :unprocessable_content }
      format.turbo_stream { render action_name, status: :unprocessable_content }
    end
  end

  def entity_save_destination
    return @return_to if @card_transaction.blank?

    new_card_transaction_path(
      user_card_id: @card_transaction.user_card_id,
      card_transaction: { entity_id: @entity.id }
    )
  end

  def set_return_to
    @return_to = entity_navigation_destination(params[:return_to])
  end

  def entity_navigation_destination(raw)
    Navigation::Entities.new(raw:, fallback: entities_path, current_user:).destination
  end

  def entity_navigation_return_param(raw)
    destination = entity_navigation_destination(raw)
    destination unless destination == entities_path
  end

  def build_index_context
    @index_context = {
      search_term: search_params[:search_term],
      status: Array(filter_params[:status]).compact_blank
    }
  end

  def entities_scope
    build_index_context if @index_context.blank?

    scope = current_user.entities.includes(friendship: { user: :profile, friend: :profile })
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

  def entity_destroy_failure_notification
    return notification_model(:not_destroyeda, Entity) if @entity.built_in?

    @entity.errors.full_messages.to_sentence.presence || notification_model(:not_destroyed_because_has_transactionsa, Entity)
  end

  def search_params
    params.permit(:search_term)
  end

  def filter_params
    return {} if params[:entity].blank?

    params.require(:entity).permit(status: [])
  end
end
