# frozen_string_literal: true

class PiggyBankReconciliations::Result
  STATUSES = %i[applied noop stale invalid failed].freeze

  attr_reader :status, :reason_code, :plan, :investment, :return_cash_transaction, :operation, :issues

  def initialize(status:, reason_code: nil, plan: nil, investment: nil, return_cash_transaction: nil, operation: nil, issues: [])
    raise ArgumentError, "invalid reconciliation apply status: #{status.inspect}" unless status.to_sym.in?(STATUSES)

    @status = status.to_sym
    @reason_code = reason_code&.to_sym
    @plan = plan
    @investment = investment
    @return_cash_transaction = return_cash_transaction || plan&.return_cash_transaction
    @operation = operation
    @issues = (issues.presence || plan&.issues || []).map(&:to_sym).uniq.sort.freeze
    freeze
  end

  def applied? = status == :applied
  def noop? = status == :noop
  def stale? = status == :stale
  def invalid? = status == :invalid
  def failed? = status == :failed
  def success? = applied? || noop?
  def valid? = success?

  def delta_cents = plan&.delta_cents
  def observed_net_cents = plan&.observed_net_cents
  def recorded_remaining_cents = plan&.recorded_remaining_cents
  def digest = plan&.digest

  def to_h
    {
      status:,
      reason_code:,
      plan: plan&.to_h,
      investment_id: investment&.id,
      return_cash_transaction_id: return_cash_transaction&.id,
      operation_id: operation&.id,
      issues:
    }.freeze
  end
end
