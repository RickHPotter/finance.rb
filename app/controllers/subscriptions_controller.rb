# frozen_string_literal: true

class SubscriptionsController < ApplicationController
  include TabsConcern
  include ContextHelper

  before_action :set_subscription, only: %i[edit update destroy]
  before_action :set_categories, :set_entities, only: %i[new create edit update]
  before_action :set_subscription_tabs

  def index
    build_index_context
    @subscriptions = subscriptions_scope

    respond_to do |format|
      format.html { render Views::Subscriptions::Index.new(subscriptions: @subscriptions, index_context: @index_context, mobile: @mobile) }
      format.turbo_stream
    end
  end

  def new
    @subscription = current_user.subscriptions.new

    respond_to do |format|
      format.html { render Views::Subscriptions::New.new(current_user:, subscription: @subscription) }
      format.turbo_stream
    end
  end

  def create
    @subscription = current_user.subscriptions.new(subscription_params.except(:category_id, :entity_id))
    assign_associations
    handle_save(:new)
  end

  def edit
    respond_to do |format|
      format.html { render Views::Subscriptions::Edit.new(current_user:, subscription: @subscription) }
      format.turbo_stream
    end
  end

  def update
    @subscription.assign_attributes(subscription_params.except(:category_id, :entity_id))
    assign_associations
    handle_save(:edit)
  end

  def destroy
    @subscription.destroy if @subscription.can_be_destroyed?
    load_subscriptions

    respond_to do |format|
      format.html do
        if @subscription.destroyed?
          redirect_to subscriptions_path, notice: notification_model(:destroyed, Subscription)
        else
          redirect_to subscriptions_path, alert: notification_model(:not_destroyed, Subscription)
        end
      end
      format.turbo_stream
    end
  end

  private

  def set_subscription_tabs
    set_tabs(active_menu: :cash, active_sub_menu: :subscription)
  end

  def set_subscription
    @subscription = current_user.subscriptions.find(params[:id])
  end

  def load_subscriptions
    @subscriptions = subscriptions_scope
  end

  def build_index_context
    @index_context = {
      current_user:,
      search_term: search_subscription_params[:search_term],
      category_id: Array(subscription_filter_params[:category_id]).compact_blank,
      entity_id: Array(subscription_filter_params[:entity_id]).compact_blank,
      status: Array(subscription_filter_params[:status]).compact_blank
    }
  end

  def subscriptions_scope
    build_index_context if @index_context.blank?

    scope = current_user.subscriptions.includes(:categories, :entities).left_outer_joins(:categories, :entities)
    scope = scope.where(status: @index_context[:status]) if @index_context[:status].present?
    scope = scope.where(categories: { id: @index_context[:category_id] }) if @index_context[:category_id].present?
    scope = scope.where(entities: { id: @index_context[:entity_id] }) if @index_context[:entity_id].present?

    if @index_context[:search_term].present?
      search_term = "%#{@index_context[:search_term].strip}%"
      scope = scope.where("finance_subscriptions.description ILIKE :search OR finance_subscriptions.comment ILIKE :search", search: search_term)
    end

    scope.distinct.order(:status, :description)
  end

  def assign_associations
    @subscription.categories = current_user.categories.where(id: subscription_params[:category_id]).order(:category_name)
    @subscription.entities = current_user.entities.where(id: subscription_params[:entity_id]).order(:entity_name)
  end

  def handle_save(view_name)
    if @subscription.save
      load_subscriptions

      respond_to do |format|
        format.html { redirect_to subscriptions_path, notice: notification_model(view_name == :new ? :created : :updated, Subscription) }
        format.turbo_stream
      end
    else
      respond_to do |format|
        format.html do
          if view_name == :new
            render(Views::Subscriptions::New.new(current_user:, subscription: @subscription))
          else
            render(Views::Subscriptions::Edit.new(current_user:, subscription: @subscription), status: :unprocessable_content)
          end
        end
        format.turbo_stream do
          action_to_render = view_name == :new ? :create : :update

          render(action_to_render, status: :unprocessable_content)
        end
      end
    end
  end

  def subscription_params
    return {} if params[:subscription].blank?

    params.require(:subscription).permit(
      :description, :comment, :price, :status, :user_id, :category_id, :entity_id,
      cash_transactions_attributes: %i[id date price paid user_bank_account_id _destroy],
      card_transactions_attributes: %i[id date month year price paid user_card_id _destroy]
    )
  end

  def search_subscription_params
    params.permit(:search_term)
  end

  def subscription_filter_params
    return {} if params[:subscription].blank?

    params.require(:subscription).permit(category_id: [], entity_id: [], status: [])
  end
end
