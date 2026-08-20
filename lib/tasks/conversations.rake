# frozen_string_literal: true

namespace :conversations do
  desc "Report conversation and message history anomalies without changing data"
  task inventory: :environment do
    puts Logic::Conversations::Inventory.new.call.to_text
  end

  desc "Fail unless conversation and message history passes the deployment inventory"
  task verify: :environment do
    report = Logic::Conversations::Inventory.new.call
    puts report.to_text
    abort "Conversation/message inventory is not clean." unless report.clean?
  end

  desc "Plan or apply canonical friendship-backed conversation identity"
  task backfill: :environment do
    apply = ActiveModel::Type::Boolean.new.cast(ENV.fetch("CONVERSATION_BACKFILL_APPLY", false))
    result = Logic::Conversations::CanonicalBackfill.new(apply:).call

    puts result.to_text
    puts "Dry run only. Set CONVERSATION_BACKFILL_APPLY=1 to apply." unless result.applied?
  end
end
