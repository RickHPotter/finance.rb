# frozen_string_literal: true

# Controller for Pages SPA
class PagesController < ApplicationController
  include TabsConcern

  def donation
    render Views::Pages::Donation.new
  end

  def notification
    render Views::Pages::Notification.new
  end
end
