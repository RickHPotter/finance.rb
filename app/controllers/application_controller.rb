# frozen_string_literal: true

# God Controller
class ApplicationController < ActionController::Base
  # @callbacks ...............................................................
  before_action :configure_permitted_parameters, if: :devise_controller?
  before_action :authenticate_user!, unless: :devise_controller?
  before_action :resolve_current_context, unless: :devise_controller?
  before_action :set_locale
  before_action :redirect_turbo_stream_requests_to_html
  around_action :with_audit_operation, if: :audit_mutating_request?
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
    current_state = current_context.cash_installments.order(:order_id).pluck(:balance)
    Logic::RecalculateBalancesService.new(user: current_user, context: current_context).call

    new_state = current_context.cash_installments.order(:order_id).pluck(:balance)
    @f.lee if current_state != new_state
  end

  # @private_instance_methods ................................................
  private

  def resolve_current_context
    current_context
  end

  def current_context
    return unless current_user

    @current_context ||= begin
      context = current_user.contexts.active.find_by(id: session[:current_context_id]) || current_user.ensure_main_context!
      session[:current_context_id] = context.id
      context
    end
  end
  helper_method :current_context

  def with_audit_operation(&)
    Audit::Operation.run(
      actor: current_user,
      context: current_context,
      source: audit_operation_source,
      request_id: request.request_id,
      parent_operation_id: audit_parent_operation_id,
      &
    )
  end

  def audit_mutating_request?
    request.request_method_symbol.in?(%i[post put patch delete])
  end

  def audit_operation_source
    :web
  end

  def audit_parent_operation_id
    nil
  end

  def redirect_turbo_stream_requests_to_html
    return unless request.get? && request.path.ends_with?(".turbo_stream")

    redirect_to request.original_fullpath.sub(".turbo_stream", ""), status: :moved_permanently
  end
end
