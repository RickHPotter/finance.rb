# frozen_string_literal: true

class SubscriptionsController < ApplicationController
  skip_before_action :verify_authenticity_token

  def create
    subscription = current_user.subscriptions.find_or_initialize_by(endpoint: subscription_params[:endpoint])
    subscription.assign_attributes(p256dh: subscription_params[:keys][:p256dh], auth: subscription_params[:keys][:auth])
    subscription.save

    head :ok
  end

  def subscription_params
    params.require(:subscription).permit(:endpoint, keys: %i[p256dh auth])
  end
end
