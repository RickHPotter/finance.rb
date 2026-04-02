# frozen_string_literal: true

class SettingsController < ApplicationController
  include TabsConcern

  before_action :set_settings_tabs

  def show
    render Views::Settings::Show.new(show_exchange_audit: current_user.admin?)
  end

  private

  def set_settings_tabs
    set_tabs(active_menu: :hub, active_sub_menu: :settings)
  end
end
