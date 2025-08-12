# frozen_string_literal: true

# Controller for Pages SPA
class PagesController < ApplicationController
  include TabsConcern

  before_action :set_tabs, only: :index

  def index
    render Views::Pages::Index.new
  end

  def donation
    render Views::Pages::Donation.new
  end

  def notification
    render Views::Pages::Notification.new
  end
end
