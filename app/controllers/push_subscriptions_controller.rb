# frozen_string_literal: true

class PushSubscriptionsController < ApplicationController
  skip_before_action :verify_authenticity_token

  def create
    push_subscription = current_user.push_subscriptions.find_or_initialize_by(endpoint: push_subscription_params[:endpoint])
    push_subscription.assign_attributes(p256dh: push_subscription_params[:keys][:p256dh], auth: push_subscription_params[:keys][:auth])
    push_subscription.save

    head :ok
  end

  def push_subscription_params
    params.require(:push_subscription).permit(:endpoint, keys: %i[p256dh auth])
  end
end
