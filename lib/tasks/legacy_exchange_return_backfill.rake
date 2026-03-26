# frozen_string_literal: true

namespace :legacy_exchange_return_backfill do # rubocop:disable Metrics/BlockLength
  desc "Export a read-only audit report for legacy EXCHANGE RETURN transactions with outdated installment structure"
  task audit: :environment do
    output = ENV["OUTPUT"].presence || "tmp/legacy_exchange_return_audit.json"
    report = Logic::LegacyExchangeReturnAudit.new.call

    FileUtils.mkdir_p(File.dirname(output))
    File.write(output, JSON.pretty_generate(report))

    puts "Legacy exchange return audit written to #{output}"
    puts "Candidates: #{report[:candidates_count]}"
  end

  desc "Normalize legacy EXCHANGE RETURN installments from canonical exchanges"
  task apply: :environment do
    output = ENV["OUTPUT"].presence || "tmp/legacy_exchange_return_apply.json"
    dry_run = ActiveModel::Type::Boolean.new.cast(ENV.fetch("DRY_RUN", "true"))
    ids = ENV["IDS"].to_s.split(",").compact_blank

    report = Logic::LegacyExchangeReturnRunner.new(ids:, dry_run:).call

    FileUtils.mkdir_p(File.dirname(output))
    File.write(output, JSON.pretty_generate(report))

    puts "Legacy exchange return apply report written to #{output}"
    puts "Dry run: #{report[:dry_run]}"
    puts "Updated transactions: #{report[:updated_count]}"
    puts "Skipped transactions: #{report[:skipped_count]}"
  end

  desc "Export a read-only audit report for legacy standalone EXCHANGE RETURN consolidation families"
  task consolidation_audit: :environment do
    output = ENV["OUTPUT"].presence || "tmp/legacy_exchange_return_consolidation_audit.json"
    report = Logic::LegacyExchangeReturnConsolidationAudit.new.call

    FileUtils.mkdir_p(File.dirname(output))
    File.write(output, JSON.pretty_generate(report))

    puts "Legacy exchange return consolidation audit written to #{output}"
    puts "Candidates: #{report[:candidates_count]}"
  end

  desc "Consolidate legacy standalone EXCHANGE RETURN families into one shared cash transaction"
  task consolidation_apply: :environment do
    output = ENV["OUTPUT"].presence || "tmp/legacy_exchange_return_consolidation_apply.json"
    dry_run = ActiveModel::Type::Boolean.new.cast(ENV.fetch("DRY_RUN", "true"))
    ids = ENV["IDS"].to_s.split(",").compact_blank

    report = Logic::LegacyExchangeReturnConsolidationRunner.new(ids:, dry_run:).call

    FileUtils.mkdir_p(File.dirname(output))
    File.write(output, JSON.pretty_generate(report))

    puts "Legacy exchange return consolidation apply report written to #{output}"
    puts "Dry run: #{report[:dry_run]}"
    puts "Updated families: #{report[:updated_count]}"
    puts "Skipped families: #{report[:skipped_count]}"
  end
end
