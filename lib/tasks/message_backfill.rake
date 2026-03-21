# frozen_string_literal: true

namespace :message_backfill do
  desc "Export a read-only audit report for classifying all messages before conversation backfill"
  task audit: :environment do
    output = ENV["OUTPUT"].presence || "tmp/message_backfill_audit.json"
    report = Logic::MessageBackfillAudit.new.call

    FileUtils.mkdir_p(File.dirname(output))
    File.write(output, JSON.pretty_generate(report))

    puts "Message backfill audit written to #{output}"
    puts "Counts: #{report[:counts]}"
  end

  desc "Backfill messages into human or assistant conversations"
  task apply: :environment do
    output = ENV["OUTPUT"].presence || "tmp/message_backfill_apply.json"
    dry_run = ActiveModel::Type::Boolean.new.cast(ENV.fetch("DRY_RUN", "true"))
    report = Logic::MessageBackfillRunner.new(dry_run:).call

    FileUtils.mkdir_p(File.dirname(output))
    File.write(output, JSON.pretty_generate(report))

    puts "Message backfill apply report written to #{output}"
    puts "Dry run: #{report[:dry_run]}"
    puts "Moved messages: #{report[:moved_messages_count]}"
  end
end
