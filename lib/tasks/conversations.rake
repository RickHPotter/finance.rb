# frozen_string_literal: true

namespace :conversations do
  desc "Report conversation and message history anomalies without changing data"
  task inventory: :environment do
    puts Logic::Conversations::Inventory.new.call.to_text
  end
end
