# frozen_string_literal: true

class V1::PagesController < V1::ApplicationController
  include V1::TabsConcern

  before_action :set_tabs, only: :index

  def index
    render Views::V1::Pages::Index.new
  end

  def donation
    render Views::V1::Pages::Donation.new
  end

  def notification
    render Views::V1::Pages::Notification.new
  end
end
