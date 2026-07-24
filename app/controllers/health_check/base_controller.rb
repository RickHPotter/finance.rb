# frozen_string_literal: true

class HealthCheck::BaseController < ApplicationController
  include TabsConcern

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
end
