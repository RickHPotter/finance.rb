# frozen_string_literal: true

# God Controller
class ApplicationController < ActionController::Base
  # @callbacks ...............................................................
  before_action :configure_permitted_parameters, if: :devise_controller?
  before_action :authenticate_user!
  before_action :set_locale

  include ContextHelper

  # @protected_instance_methods ..............................................
  protected

  # Configure permitted parameters for Devise controllers.
  #
  # @return [void].
  #
  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: %i[first_name last_name])
    devise_parameter_sanitizer.permit(:account_update, keys: %i[first_name last_name])
  end

  # Set locale from params[:locale] or cookies[:locale]
  #
  # @return [void]
  #
  def set_locale
    local_param = params[:locale]
    local_cookie = cookies[:locale]

    local_cookie = local_param if local_param
    I18n.locale = local_cookie if local_cookie
  end
end
