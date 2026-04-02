# frozen_string_literal: true

class RemoveLaterMigration < ActiveRecord::Migration[8.1]
  EXCHANGE_BACKFILL_CONFIG_PATH = Rails.root.join("db/data/exchange_backfill_config.json")

  def up
    standard_cleanup_runners.each do |runner_config|
      run_cleanup_runner(*runner_config)
    end

    run_exchange_backfill_runner

    run_cleanup_runner(
      "MessageBackfillRunner",
      Logic::MessageBackfillRunner.new(dry_run: false),
      :dry_run,
      :processed_messages_count,
      :moved_messages_count,
      :rewritten_messages_count
    )
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  def standard_cleanup_runners
    [
      [ "ExchangeIntentCorrectionRunner", Logic::ExchangeIntentCorrectionRunner.new(dry_run: false), :dry_run, :candidate_count, :updated_messages_count,
        :skipped_count ],
      [ "ExchangeChainReferenceRunner", Logic::ExchangeChainReferenceRunner.new(dry_run: false), :dry_run, :candidate_count, :supported_count, :updated_row_count,
        :updated_change_count, :skipped_count ],
      [ "StandaloneExchangeParentReferenceRunner", Logic::StandaloneExchangeParentReferenceRunner.new(dry_run: false), :dry_run, :processed_count, :updated_count,
        :skipped_count ],
      [ "LegacyExchangeReturnRunner", Logic::LegacyExchangeReturnRunner.new(dry_run: false), :dry_run, :processed_count, :updated_count, :skipped_count ],
      [ "LegacyExchangeReturnConsolidationRunner", Logic::LegacyExchangeReturnConsolidationRunner.new(dry_run: false), :dry_run, :processed_count, :updated_count,
        :skipped_count ],
      [ "StandaloneExchangeIntegrityRunner", Logic::StandaloneExchangeIntegrityRunner.new(dry_run: false), :dry_run, :processed_count, :updated_count,
        :skipped_count ],
      [ "CardBoundExchangeIntegrityRunner", Logic::CardBoundExchangeIntegrityRunner.new(dry_run: false), :dry_run, :processed_count, :updated_count, :skipped_count ]
    ]
  end

  def run_cleanup_runner(label, runner, *summary_keys, skipped_key: :skipped_count)
    result = runner.call

    puts label
    puts JSON.pretty_generate(result.slice(*summary_keys))

    return result unless result[skipped_key].to_i.positive?

    raise ActiveRecord::IrreversibleMigration, "#{label} skipped #{result[skipped_key]} rows"
  end

  def run_exchange_backfill_runner
    config = exchange_backfill_config
    return if config.blank?

    run_cleanup_runner(
      "ExchangeBackfillRunner",
      Logic::ExchangeBackfillRunner.new(
        user_a: User.find(config.fetch("user_a_id")),
        user_b: User.find(config.fetch("user_b_id")),
        mapping: config.fetch("mapping"),
        dry_run: false
      ),
      :dry_run,
      :processed_cases,
      :updated_messages_count,
      :skipped_cases_count,
      skipped_key: :skipped_cases_count
    )
  end

  def exchange_backfill_config
    return unless File.exist?(EXCHANGE_BACKFILL_CONFIG_PATH)

    JSON.parse(File.read(EXCHANGE_BACKFILL_CONFIG_PATH))
  end
end
