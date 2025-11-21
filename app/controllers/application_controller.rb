# frozen_string_literal: true

# God Controller
class ApplicationController < ActionController::Base
  # @callbacks ...............................................................
  before_action :configure_permitted_parameters, if: :devise_controller?
  before_action :authenticate_user!, unless: :devise_controller?
  before_action :set_locale
  before_action :redirect_turbo_stream_requests_to_html
  # TODO: keep this for in development to see if it detects any bugs
  after_action :check_reasoning, if: -> { Rails.env.development? && !devise_controller? && action_name.in?(%w[create update destroy pay pay_multiple]) }

  # @protected_instance_methods ..............................................

  protected

  # Configure permitted parameters for Devise controllers.
  #
  # @return [void].
  #
  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: %i[first_name last_name])
    devise_parameter_sanitizer.permit(:account_update, keys: %i[first_name last_name locale])
  end

  # Set locale from params[:locale] or cookies[:locale]
  #
  # @return [void]
  #
  def set_locale
    I18n.locale =
      if respond_to?(:current_user) && current_user&.locale.present?
        current_user.locale
      elsif params[:locale].present?
        cookies[:locale] = params[:locale]
      else
        cookies[:locale] || I18n.default_locale
      end
  end

  def check_reasoning
    current_state = current_user.cash_installments.order(:order_id).pluck(:balance)
    Logic::RecalculateBalancesService.new(user: current_user).call

    new_state = current_user.cash_installments.order(:order_id).pluck(:balance)
    @f.lee if current_state != new_state
  end

  # @private_instance_methods ................................................
  private

  def redirect_turbo_stream_requests_to_html
    return unless request.get? && request.path.ends_with?(".turbo_stream")

    redirect_to request.original_fullpath.sub(".turbo_stream", ""), status: :moved_permanently
  end
end
