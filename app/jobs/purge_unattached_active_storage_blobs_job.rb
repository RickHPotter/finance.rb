# frozen_string_literal: true

class PurgeUnattachedActiveStorageBlobsJob < ApplicationJob
  queue_as :default

  def perform
    ActiveStorage::Blob.unattached.where(created_at: ...24.hours.ago).find_each(&:purge_later)
  end
end
