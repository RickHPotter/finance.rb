# frozen_string_literal: true

class Admin::BackupsController < ApplicationController
  def data_backup
    return head :unauthorized unless current_user

    service = Export::DatabaseBackupService.new(current_user)
    service.run!

    path = service.path

    return head :not_found unless path

    send_file path,
              filename: "30fev backup.zip",
              type: "application/zip",
              disposition: "attachment"
  end
end
