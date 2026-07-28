# frozen_string_literal: true

class HealthCheck::Repairs::CanonicalReferenceApplier
  attr_reader :preview, :scope

  def initialize(scope:, preview:)
    @scope = scope
    @preview = preview
  end

  def call
    result = Logic::ExchangeChainReferenceRunner.new(
      rows: scoped_rows,
      source_transaction_ids: [ preview.finding_id ],
      dry_run: false
    ).call

    expected_count = preview.changes.size
    actual_count = result[:updated_change_count].to_i
    raise HealthCheck::Repairs::Apply::MutationError unless actual_count == expected_count && result[:skipped_count].to_i.zero?

    result
  end

  private

  def scoped_rows
    rows = Logic::ExchangeTrioAudit.new(
      current_user: scope.user,
      current_context: scope.context,
      connected_user_id: scope.connected_user&.id
    ).call
    Logic::ExchangeAuditSelectionProjector.new(rows:).call
  end
end
