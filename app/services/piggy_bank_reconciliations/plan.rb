# frozen_string_literal: true

class PiggyBankReconciliations::Plan
  STATUSES = %i[ready noop invalid].freeze

  attr_reader :status, :reason_code, :return_cash_transaction, :investment_type_id,
              :observed_on, :recorded_remaining_cents, :observed_net_cents, :delta_cents,
              :lifetime_recorded_cents, :paid_cents, :resulting_lifetime_cents, :digest, :issues

  def initialize(status:, **attributes)
    attributes.assert_valid_keys(
      :reason_code,
      :return_cash_transaction,
      :investment_type_id,
      :observed_on,
      :recorded_remaining_cents,
      :observed_net_cents,
      :delta_cents,
      :lifetime_recorded_cents,
      :paid_cents,
      :resulting_lifetime_cents,
      :digest,
      :issues
    )
    raise ArgumentError, "invalid reconciliation status" unless status.to_sym.in?(STATUSES)

    @status = status.to_sym
    @reason_code = attributes[:reason_code]&.to_sym
    @return_cash_transaction = attributes[:return_cash_transaction]
    @investment_type_id = attributes[:investment_type_id]
    @observed_on = attributes[:observed_on]
    @recorded_remaining_cents = attributes[:recorded_remaining_cents]
    @observed_net_cents = attributes[:observed_net_cents]
    @delta_cents = attributes[:delta_cents]
    @lifetime_recorded_cents = attributes[:lifetime_recorded_cents]
    @paid_cents = attributes[:paid_cents]
    @resulting_lifetime_cents = attributes[:resulting_lifetime_cents]
    @digest = attributes[:digest]&.dup&.freeze
    @issues = Array(attributes[:issues]).map(&:to_sym).uniq.sort.freeze
    freeze
  end

  def valid? = ready? || noop?
  def ready? = status == :ready
  def noop? = status == :noop
  def invalid? = status == :invalid

  def to_h
    {
      status:,
      reason_code:,
      return_cash_transaction_id: return_cash_transaction&.id,
      investment_type_id:,
      observed_on:,
      recorded_remaining_cents:,
      observed_net_cents:,
      delta_cents:,
      lifetime_recorded_cents:,
      paid_cents:,
      resulting_lifetime_cents:,
      digest:,
      issues:
    }.freeze
  end
end
