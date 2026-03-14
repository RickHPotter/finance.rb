# frozen_string_literal: true

class StaticController < ApplicationController
  include TabsConcern

  before_action :set_static_tabs

  def donation
    render Views::Static::Donation.new
  end

  def notification
    render Views::Static::Notification.new
  end

  private

  def set_static_tabs
    set_tabs(active_menu: :basic, active_sub_menu: :conversation)
  end
end
