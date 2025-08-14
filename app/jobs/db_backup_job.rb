# frozen_string_literal: true

class DbBackupJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info "Running DB backup job"

    Export::DatabaseService.backup
  end
end
