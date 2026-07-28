# frozen_string_literal: true

class Admin::SettingsController < ApplicationController # rubocop:disable Metrics/ClassLength
  include TabsConcern

  before_action :require_admin!
  before_action :set_settings_tabs

  def exchange_audit
    middle_overrides = sanitized_middle_overrides
    receiver_overrides = sanitized_receiver_overrides
    selected_connected_user_id = sanitized_connected_user_id
    scope = audit_scope_for(middle_overrides, receiver_overrides, selected_connected_user_id)
    rows = scope[:rows]
    reference_audit = Logic::ExchangeChainReferenceAudit.new(rows:, middle_overrides:, receiver_overrides:).call

    render Views::Admin::Settings::ExchangeAudit.new(
      rows:,
      middle_overrides:,
      receiver_overrides:,
      reference_audit:,
      connections: scope[:connections],
      current_user_id: current_user.id,
      selected_connected_user_id: scope[:selected_connected_user_id]
    )
  end

  def convert_exchange_audit_loan_intent
    source_transaction_id = params.require(:source_transaction_id)
    intent_conversion_result = misplaced_loan_exchange_audit.convert_exchange_audit_issue!(source_id: source_transaction_id)

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: exchange_audit_intent_conversion_streams(intent_conversion_result)
      end

      format.html { render_exchange_audit_with_intent_conversion_result(intent_conversion_result) }
    end
  end

  def exchange_return_audit
    render Views::Admin::Settings::ExchangeReturnAudit.new
  end

  def exchange_return_audit_issue_bucket
    issue_code = sanitized_exchange_return_issue_code

    render Views::Admin::Settings::ExchangeReturnAudit.new(
      rows: exchange_return_audit_rows(issue_code:),
      frame_id: "settings_exchange_return_audit_#{issue_code}_content",
      bucket_issue: issue_code
    )
  end

  def exchange_return_audit_misplaced_loans
    rows = misplaced_loan_exchange_audit.call

    render Views::Admin::Settings::ExchangeAuditMisplacedLoans.new(rows:)
  end

  def card_exchange_projection_audit
    rows = Logic::CardExchangeProjectionAudit.new(
      current_user: current_user,
      current_context: current_context,
      status_filter: sanitized_card_projection_status_filter
    ).call

    render Views::Admin::Settings::CardExchangeProjectionAudit.new(rows:)
  end

  def piggy_bank_audit
    rows = Logic::PiggyBankAudit.new(current_user:, current_context:).call

    render Views::Admin::Settings::PiggyBankAudit.new(rows:)
  end

  def mark_exchange_return_source_as_fee
    entity_transaction = exchange_return_source_entity_transaction
    issue_code = sanitized_exchange_return_issue_code
    affected_transaction_ids = affected_exchange_return_ids_for(entity_transaction)
    apply_exchange_return_source_percentage!(entity_transaction)

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: exchange_return_audit_action_streams(
          issue_code:,
          transaction_ids: affected_transaction_ids
        )
      end

      format.html do
        render Views::Admin::Settings::ExchangeReturnAudit.new(
          rows: exchange_return_audit_rows(issue_code:),
          frame_id: "settings_exchange_return_audit_#{issue_code}_content",
          bucket_issue: issue_code
        )
      end
    end
  end

  def convert_misplaced_loan
    result = misplaced_loan_exchange_audit.convert!(source_id: params.require(:source_transaction_id))

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.update(
            :settings_exchange_return_audit_misplaced_loans_result,
            Views::Admin::Settings::ExchangeAuditMisplacedLoans.new(rows: [], result:, result_only: true)
          ),
          turbo_stream.remove(misplaced_loan_row_dom_id(result[:source_id]))
        ]
      end

      format.html do
        render Views::Admin::Settings::ExchangeAuditMisplacedLoans.new(rows: misplaced_loan_exchange_audit.call, result:)
      end
    end
  end

  def apply_exchange_audit
    middle_overrides = sanitized_middle_overrides
    receiver_overrides = sanitized_receiver_overrides
    selected_connected_user_id = sanitized_connected_user_id
    source_transaction_id = params.require(:source_transaction_id).to_i

    return apply_exchange_audit_turbo(source_transaction_id:, middle_overrides:, receiver_overrides:, selected_connected_user_id:) if request.format.turbo_stream?

    scope = audit_scope_for(middle_overrides, receiver_overrides, selected_connected_user_id)
    return head :not_found unless scope[:rows].any? { |row| row.dig(:source, :id) == source_transaction_id }

    apply_result = Logic::ExchangeChainReferenceRunner.new(
      source_transaction_ids: [ source_transaction_id ],
      dry_run: false,
      middle_overrides:,
      receiver_overrides:
    ).call
    scope = audit_scope_for(middle_overrides, receiver_overrides, selected_connected_user_id)
    rows = scope[:rows]
    reference_audit = Logic::ExchangeChainReferenceAudit.new(rows:, middle_overrides:, receiver_overrides:).call

    render Views::Admin::Settings::ExchangeAudit.new(
      rows:,
      middle_overrides:,
      receiver_overrides:,
      reference_audit:,
      apply_result:,
      connections: scope[:connections],
      current_user_id: current_user.id,
      selected_connected_user_id: scope[:selected_connected_user_id]
    )
  end

  private

  def audit_operation_source
    :admin_repair
  end

  def require_admin!
    return if current_user&.admin?

    head :not_found
  end

  def set_settings_tabs
    set_tabs(active_menu: :hub, active_sub_menu: :settings)
  end

  def render_exchange_audit_with_intent_conversion_result(intent_conversion_result)
    middle_overrides = sanitized_middle_overrides
    receiver_overrides = sanitized_receiver_overrides
    selected_connected_user_id = sanitized_connected_user_id
    scope = audit_scope_for(middle_overrides, receiver_overrides, selected_connected_user_id)
    rows = scope[:rows]
    reference_audit = Logic::ExchangeChainReferenceAudit.new(rows:, middle_overrides:, receiver_overrides:).call

    render Views::Admin::Settings::ExchangeAudit.new(
      rows:,
      middle_overrides:,
      receiver_overrides:,
      reference_audit:,
      intent_conversion_result:,
      connections: scope[:connections],
      current_user_id: current_user.id,
      selected_connected_user_id: scope[:selected_connected_user_id]
    )
  end

  def apply_exchange_audit_turbo(source_transaction_id:, middle_overrides:, receiver_overrides:, selected_connected_user_id:)
    apply_result = run_exchange_audit_reference_fix(source_transaction_id:, middle_overrides:, receiver_overrides:)

    render turbo_stream: exchange_audit_apply_streams(
      apply_result:,
      source_transaction_id:,
      middle_overrides:,
      receiver_overrides:,
      selected_connected_user_id:
    )
  end

  def audit_scope_for(middle_overrides, receiver_overrides, selected_connected_user_id)
    base_rows = Logic::ExchangeTrioAudit.new(current_user: current_user).call
    projected_rows = Logic::ExchangeAuditSelectionProjector.new(rows: base_rows, middle_overrides:, receiver_overrides:).call

    Logic::ExchangeAuditConnections.new(
      rows: projected_rows,
      current_user:,
      selected_connected_user_id:
    ).call
  end

  def misplaced_loan_exchange_audit
    Logic::MisplacedLoanExchangeAudit.new(
      current_user: current_user,
      connected_user_id: sanitized_connected_user_id
    )
  end

  def sanitized_middle_overrides
    raw_middle_overrides = params[:middle_overrides]
    sanitize_override_hash(raw_middle_overrides)
  end

  def sanitized_receiver_overrides
    raw_receiver_overrides = params[:receiver_overrides]
    sanitize_override_hash(raw_receiver_overrides)
  end

  def sanitized_connected_user_id
    raw_connected_user_id = params[:connected_user_id]
    return if raw_connected_user_id.blank?

    raw_connected_user_id.to_i
  end

  def sanitized_exchange_return_status_filter
    raw_status_filter = params[:status_filter].to_s
    return "pending" if raw_status_filter.blank?

    %w[paid pending].include?(raw_status_filter) ? raw_status_filter : "pending"
  end

  def sanitized_card_projection_status_filter
    raw_status_filter = params[:status_filter].to_s
    return "pending" if raw_status_filter.blank?

    %w[paid pending].include?(raw_status_filter) ? raw_status_filter : "pending"
  end

  def sanitized_exchange_return_issue_code
    issue_code = params[:issue_code].to_s
    return issue_code if Views::Admin::Settings::ExchangeReturnAudit::ISSUE_BUCKETS.include?(issue_code)

    raise ActiveRecord::RecordNotFound
  end

  def exchange_return_source_entity_transaction
    entity_transaction = EntityTransaction.find(params.require(:entity_transaction_id))
    transactable = entity_transaction.transactable

    return entity_transaction if transactable.respond_to?(:context_id) && transactable.context_id == current_context.id

    raise ActiveRecord::RecordNotFound
  end

  def affected_exchange_return_ids_for(entity_transaction)
    entity_transaction.exchanges
                      .joins(:cash_transaction)
                      .where(cash_transactions: { context_id: current_context.id })
                      .merge(CashTransaction.exchange_return)
                      .pluck(:cash_transaction_id)
                      .uniq
  end

  def exchange_return_audit_rows(issue_code:, transaction_ids: nil)
    Logic::ExchangeReturnAudit.new(
      current_user: current_user,
      current_context: current_context,
      issue_filter: issue_code,
      status_filter: sanitized_exchange_return_status_filter,
      transaction_ids:
    ).call
  end

  def exchange_return_audit_action_streams(issue_code:, transaction_ids:)
    rows_by_id = exchange_return_audit_rows(issue_code:, transaction_ids:).index_by { |row| row[:id] }

    transaction_ids.map do |transaction_id|
      row = rows_by_id[transaction_id]
      target = exchange_return_audit_row_dom_id(transaction_id)
      next turbo_stream.remove(target) if row.blank?

      turbo_stream.replace(
        target,
        Views::Admin::Settings::ExchangeReturnAudit.new(row:, bucket_issue: issue_code)
      )
    end
  end

  def exchange_return_audit_row_dom_id(id)
    "exchange_return_audit_row_#{id}"
  end

  def misplaced_loan_row_dom_id(source_id)
    "misplaced_loan_row_#{source_id}"
  end

  def exchange_audit_intent_conversion_streams(result)
    streams = [
      turbo_stream.update(
        :settings_exchange_audit_intent_conversion_result,
        Views::Admin::Settings::ExchangeAudit.new(rows: [], intent_conversion_result: result, result_only: true)
      )
    ]

    streams << turbo_stream.remove(exchange_audit_row_dom_id(result[:source_id])) if result[:status] == "converted"
    streams
  end

  def exchange_audit_row_dom_id(source_id)
    "exchange_audit_row_#{source_id}"
  end

  def run_exchange_audit_reference_fix(source_transaction_id:, middle_overrides:, receiver_overrides:)
    Logic::ExchangeChainReferenceRunner.new(
      source_transaction_ids: [ source_transaction_id ],
      dry_run: false,
      middle_overrides:,
      receiver_overrides:
    ).call
  end

  def exchange_audit_apply_streams(apply_result:, source_transaction_id:, middle_overrides:, receiver_overrides:, selected_connected_user_id:)
    streams = [
      turbo_stream.update(
        :settings_exchange_audit_apply_result,
        Views::Admin::Settings::ExchangeAudit.new(rows: [], apply_result:, apply_result_only: true)
      )
    ]

    streams << exchange_audit_row_stream(source_transaction_id:, middle_overrides:, receiver_overrides:, selected_connected_user_id:)
    streams
  end

  def exchange_audit_row_stream(source_transaction_id:, middle_overrides:, receiver_overrides:, selected_connected_user_id:)
    row = refreshed_exchange_audit_row(source_transaction_id:, middle_overrides:, receiver_overrides:, selected_connected_user_id:)
    target = exchange_audit_row_dom_id(source_transaction_id)
    return turbo_stream.remove(target) if row.blank? || row[:status] == "done"

    reference_audit = Logic::ExchangeChainReferenceAudit.new(rows: [ row ], middle_overrides:, receiver_overrides:).call
    turbo_stream.replace(
      target,
      Views::Admin::Settings::ExchangeAudit.new(
        rows: [],
        row:,
        middle_overrides:,
        receiver_overrides:,
        reference_audit:,
        current_user_id: current_user.id,
        selected_connected_user_id:
      )
    )
  end

  def refreshed_exchange_audit_row(source_transaction_id:, middle_overrides:, receiver_overrides:, selected_connected_user_id:)
    scope = audit_scope_for(middle_overrides, receiver_overrides, selected_connected_user_id)
    scope[:rows].find { |row| row.dig(:source, :id) == source_transaction_id }
  end

  def apply_exchange_return_source_percentage!(entity_transaction)
    percentage = params[:loan_return_percentage].presence || entity_transaction.calculated_loan_return_percentage
    price = params[:price].presence
    price_to_be_returned = params[:price_to_be_returned].presence || price

    entity_transaction.update!(
      loan_return_percentage: percentage,
      price: price || entity_transaction.price,
      price_to_be_returned: price_to_be_returned || entity_transaction.price_to_be_returned
    )
  end

  def sanitize_override_hash(raw_overrides)
    overrides_hash = raw_overrides.respond_to?(:to_unsafe_h) ? raw_overrides.to_unsafe_h : raw_overrides.to_h

    overrides_hash.each_with_object({}) do |(source_id, target_id), result|
      next if source_id.blank? || target_id.blank?

      result[source_id.to_i] = target_id.to_i
    end
  end
end
