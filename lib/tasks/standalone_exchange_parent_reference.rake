# frozen_string_literal: true

# rubocop:disable Metrics/BlockLength
namespace :standalone_exchange_parent_reference do
  desc "Audit standalone EXCHANGE RETURN cash transactions missing their parent reference_transactable"
  task audit: :environment do
    ids = ENV.fetch("IDS", "").split(",")
    result = Logic::StandaloneExchangeParentReferenceAudit.new(ids:).call
    output_path = ENV.fetch("OUTPUT", nil)

    if output_path.present?
      File.write(output_path, JSON.pretty_generate(result))
      puts "Wrote standalone exchange parent reference audit to #{output_path}"
    else
      puts JSON.pretty_generate(result)
    end
  end

  desc "Apply parent reference_transactable to supported standalone EXCHANGE RETURN cash transactions"
  task apply: :environment do
    ids = ENV.fetch("IDS", "").split(",")
    dry_run = ActiveModel::Type::Boolean.new.cast(ENV.fetch("DRY_RUN", "true"))
    result = Logic::StandaloneExchangeParentReferenceRunner.new(ids:, dry_run:).call
    output_path = ENV.fetch("OUTPUT", nil)

    if output_path.present?
      File.write(output_path, JSON.pretty_generate(result))
      puts "Wrote standalone exchange parent reference apply result to #{output_path}"
    else
      puts JSON.pretty_generate(result)
    end
  end
end
# rubocop:enable Metrics/BlockLength
