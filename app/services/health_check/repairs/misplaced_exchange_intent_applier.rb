# frozen_string_literal: true

class HealthCheck::Repairs::MisplacedExchangeIntentApplier
  attr_reader :preview, :scope

  def initialize(scope:, preview:)
    @scope = scope
    @preview = preview
  end

  def call
    source = scope.context.cash_transactions.find(preview.finding_id)
    message_reference = preview.references.find { |reference| reference["role"] == "active_replay_messages" }

    Logic::MisplacedExchangeIntentRepair.new(
      source:,
      message_ids: message_reference&.fetch("ids", [])
    ).call
  end
end
