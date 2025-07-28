# frozen_string_literal: true

class Admin::BackupsController < ApplicationController
  before_action :authenticate_rikki

  def download_latest
    service = Export::DatabaseBackupService.new(current_user)
    service.run!

    path = service.path

    return head :not_found unless path

    send_file path,
              filename: File.basename(path),
              type: "application/zip",
              disposition: "attachment"
  end

  private

  def authenticate_rikki
    redirect_to root_path unless current_user&.email == "rikki.potteru@mail.com"
  end
end
