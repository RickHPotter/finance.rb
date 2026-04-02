# frozen_string_literal: true

# rubocop:disable Metrics/BlockLength
namespace :exchange_chain_reference do
  desc "Audit canonical reference_transactable edge rewrites for exchange chains"
  task audit: :environment do
    source_transaction_ids = ENV.fetch("IDS", "").split(",")
    result = Logic::ExchangeChainReferenceAudit.new(source_transaction_ids:).call
    output_path = ENV.fetch("OUTPUT", nil)

    if output_path.present?
      File.write(output_path, JSON.pretty_generate(result))
      puts "Wrote exchange chain reference audit to #{output_path}"
    else
      puts JSON.pretty_generate(result)
    end
  end

  desc "Apply canonical reference_transactable edge rewrites for supported exchange chains"
  task apply: :environment do
    source_transaction_ids = ENV.fetch("IDS", "").split(",")
    dry_run = ActiveModel::Type::Boolean.new.cast(ENV.fetch("DRY_RUN", "true"))
    result = Logic::ExchangeChainReferenceRunner.new(source_transaction_ids:, dry_run:).call
    output_path = ENV.fetch("OUTPUT", nil)

    if output_path.present?
      File.write(output_path, JSON.pretty_generate(result))
      puts "Wrote exchange chain reference apply result to #{output_path}"
    else
      puts JSON.pretty_generate(result)
    end
  end
end
# rubocop:enable Metrics/BlockLength
