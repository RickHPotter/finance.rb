# frozen_string_literal: true

class HealthCheck::BaseController < ApplicationController
  include TabsConcern

  rescue_from HealthCheck::Scope::Invalid, with: :render_invalid_health_check_scope

  before_action :require_admin!
  before_action :set_health_check_tabs

  private

  def require_admin!
    return if current_user&.admin?

    head :not_found
  end

  def set_health_check_tabs
    set_tabs(active_menu: :hub, active_sub_menu: :health_check)
  end

  def health_check_scope
    @health_check_scope ||= HealthCheck::Scope.new(
      user: current_user,
      context: current_context,
      connected_user: requested_connected_user,
      locale: I18n.locale
    )
  end

  def requested_connected_user
    return if params[:connected_user_id].blank?

    connected_user_id = Integer(params[:connected_user_id], exception: false)
    raise HealthCheck::Scope::Invalid, :connected_user_not_found unless connected_user_id&.positive?

    User.find_by(id: connected_user_id) || raise(HealthCheck::Scope::Invalid, :connected_user_not_found)
  end

  def health_check_redirect_params
    return {} if health_check_scope.all_connections?

    { connected_user_id: health_check_scope.connected_user.id }
  end

  def render_invalid_health_check_scope
    head :not_found
  end
end
