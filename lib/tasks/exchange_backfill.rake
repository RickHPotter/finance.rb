# frozen_string_literal: true

namespace :exchange_backfill do # rubocop:disable Metrics/BlockLength
  desc "Export a read-only audit report for exchange notifications between two users"
  task audit: :environment do
    user_a = resolve_exchange_backfill_user!(ENV.fetch("USER_A"))
    user_b = resolve_exchange_backfill_user!(ENV.fetch("USER_B"))
    output = ENV["OUTPUT"].presence || "tmp/exchange_backfill_audit.json"

    report = Logic::ExchangeBackfillAudit.new(user_a:, user_b:).call

    FileUtils.mkdir_p(File.dirname(output))
    File.write(output, JSON.pretty_generate(report))

    puts "Exchange backfill audit written to #{output}"
    puts "Cases: #{report[:cases].size}"
  end

  desc "Seed a classification mapping JSON from an audit report"
  task seed_mapping: :environment do
    input = ENV["INPUT"].presence || "tmp/exchange_backfill_audit.json"
    output = ENV["OUTPUT"].presence || "tmp/exchange_backfill_mapping.json"
    audit = JSON.parse(File.read(input))

    mapping = audit.fetch("cases").each_with_object({}) do |kase, result|
      source_id = kase.dig("source_transaction", "id").to_s

      result[source_id] = case kase["suggested_intent"]
                          when "loan_candidate"
                            "loan"
                          when "reimbursement_candidate"
                            "reimbursement"
                          end
    end

    FileUtils.mkdir_p(File.dirname(output))
    File.write(output, JSON.pretty_generate(mapping))

    puts "Exchange backfill mapping written to #{output}"
    puts "Mapped cases: #{mapping.size}"
  end

  desc "Rewrite historical exchange message headers from a reviewed mapping file"
  task apply: :environment do
    user_a = resolve_exchange_backfill_user!(ENV.fetch("USER_A"))
    user_b = resolve_exchange_backfill_user!(ENV.fetch("USER_B"))
    mapping = JSON.parse(File.read(ENV.fetch("MAPPING")))
    output = ENV["OUTPUT"].presence || "tmp/exchange_backfill_apply.json"
    dry_run = ActiveModel::Type::Boolean.new.cast(ENV.fetch("DRY_RUN", "true"))

    report = Logic::ExchangeBackfillRunner.new(user_a:, user_b:, mapping:, dry_run:).call

    FileUtils.mkdir_p(File.dirname(output))
    File.write(output, JSON.pretty_generate(report))

    puts "Exchange backfill apply report written to #{output}"
    puts "Dry run: #{report[:dry_run]}"
    puts "Updated messages: #{report[:updated_messages_count]}"
    puts "Skipped cases: #{report[:skipped_cases_count]}"
  end
end

def resolve_exchange_backfill_user!(identifier)
  scope = User.all

  user = if identifier.to_s.match?(/\A\d+\z/)
           scope.find_by(id: identifier)
         else
           scope.find_by("LOWER(email) = :value OR LOWER(first_name) = :value", value: identifier.to_s.downcase)
         end

  return user if user.present?

  raise ArgumentError, "Could not find user for #{identifier.inspect}. Try id, email, or first_name."
end
