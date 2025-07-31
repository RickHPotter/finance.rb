# frozen_string_literal: true

# God Controller
class ApplicationController < ActionController::Base
  # @callbacks ...............................................................
  before_action :configure_permitted_parameters, if: :devise_controller?
  before_action :authenticate_user!
  before_action :set_locale

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
end
