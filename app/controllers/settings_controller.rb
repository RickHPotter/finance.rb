# frozen_string_literal: true

class SettingsController < ApplicationController
  def show
    redirect_to healthcheck_path, status: :found
  end
end
