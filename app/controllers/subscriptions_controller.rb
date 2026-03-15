# frozen_string_literal: true

class SubscriptionsController < ApplicationController
  include TabsConcern
  include ContextHelper

  before_action :set_subscription, only: %i[edit update destroy]
  before_action :set_categories, :set_entities, only: %i[new create edit update]
  before_action :set_subscription_tabs

  def index
    @subscriptions = current_user.subscriptions.includes(:categories, :entities).order(:status, :description)

    respond_to do |format|
      format.html { render Views::Subscriptions::Index.new(subscriptions: @subscriptions, mobile: @mobile) }
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
    @subscription.destroy
    load_subscriptions

    respond_to do |format|
      format.html { redirect_to subscriptions_path, notice: notification_model(:destroyed, Subscription) }
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
    @subscriptions = current_user.subscriptions.includes(:categories, :entities).order(:status, :description)
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
      card_transactions_attributes: %i[id date price paid user_card_id _destroy]
    )
  end
end
