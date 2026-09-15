# frozen_string_literal: true

class PiggyBankReconciliations::Preview
  INVESTMENT_TYPE_CODE = "outros_cofrinho"

  attr_reader :user, :context, :return_cash_transaction_id, :observed_net_cents, :observed_on

  def initialize(user:, context:, return_cash_transaction_id:, observed_net_cents:, observed_on:)
    @user = user
    @context = context
    @return_cash_transaction_id = return_cash_transaction_id
    @observed_net_cents = normalize_cents(observed_net_cents)
    @observed_on = normalize_date(observed_on)
  end

  def call
    return invalid(:invalid_observation_date) if observed_on.blank?
    return invalid(:invalid_observed_value) if observed_net_cents.blank? || !observed_net_cents.positive?

    return_transaction = find_return_transaction
    return invalid(:return_not_found) if return_transaction.blank?
    return invalid(:invalid_return) unless return_transaction.generated_piggy_bank_return?
    return invalid(:settled_return, return_transaction:) unless return_transaction.cash_installments.any? { |installment| !installment.paid? }

    issues = graph_issues(return_transaction)
    return invalid(:invalid_return_graph, return_transaction:, issues:) if issues.any?

    investment_type = InvestmentType.find_by(investment_type_code: INVESTMENT_TYPE_CODE)
    return invalid(:missing_investment_configuration, return_transaction:) if investment_type.blank?

    build_valid_plan(return_transaction, investment_type:)
  end

  private

  def find_return_transaction
    context.cash_transactions
           .where(user:)
           .includes(
             :cash_installments,
             :piggy_bank_investments,
             :categories,
             piggy_bank_return_links: {
               source_cash_transaction: [ :cash_installments, { category_transactions: :category } ]
             }
           )
           .find_by(id: return_cash_transaction_id)
  end

  def build_valid_plan(return_transaction, investment_type:)
    paid_cents = return_transaction.cash_installments.select(&:paid?).sum(&:price)
    recorded_remaining_cents = return_transaction.cash_installments.reject(&:paid?).sum(&:price)
    lifetime_recorded_cents = return_transaction.price
    delta_cents = observed_net_cents - recorded_remaining_cents
    resulting_lifetime_cents = lifetime_recorded_cents + delta_cents
    status = delta_cents.zero? ? :noop : :ready

    attributes = {
      status:,
      return_cash_transaction: return_transaction,
      investment_type_id: investment_type.id,
      observed_on:,
      recorded_remaining_cents:,
      observed_net_cents:,
      delta_cents:,
      lifetime_recorded_cents:,
      paid_cents:,
      resulting_lifetime_cents:
    }
    PiggyBankReconciliations::Plan.new(**attributes, digest: digest_for(return_transaction, investment_type:, calculation: attributes))
  end

  def graph_issues(return_transaction)
    links = return_transaction.piggy_bank_return_links.to_a
    investments = return_transaction.piggy_bank_investments.to_a
    installments = return_transaction.cash_installments.to_a
    lifetime_cents = links.sum(&:return_price) + investments.sum(&:price)
    issues = []

    append_contribution_issues(issues, links, return_transaction)
    append_return_issues(issues, return_transaction, lifetime_cents)
    append_installment_issues(issues, installments, lifetime_cents, return_transaction:)
    issues
  end

  def append_contribution_issues(issues, links, return_transaction)
    issues << :missing_contributions if links.empty?
    issues << :invalid_contribution if links.any? { |link| invalid_link?(link, return_transaction) }
  end

  def append_return_issues(issues, return_transaction, lifetime_cents)
    issues << :return_total_mismatch unless return_transaction.price == lifetime_cents
    issues << :return_starting_total_mismatch unless return_transaction.starting_price == lifetime_cents
  end

  def append_installment_issues(issues, installments, lifetime_cents, return_transaction:)
    issues << :missing_installments if installments.empty?
    issues << :invalid_installment_amount if installments.any? { |installment| !installment.price.to_i.positive? }
    issues << :installment_total_mismatch unless installments.sum(&:price) == lifetime_cents
    issues << :multiple_unpaid_installments if installments.count { |installment| !installment.paid? } > 1
    issues << :return_paid_state_mismatch unless return_transaction.paid? == installments.all?(&:paid?)
  end

  def invalid_link?(link, return_transaction)
    source = link.source_cash_transaction
    source.blank? ||
      source.user_id != user.id ||
      source.context_id != context.id ||
      link.return_cash_transaction_id != return_transaction.id ||
      !source.piggy_bank_source?
  end

  def digest_for(return_transaction, investment_type:, calculation:)
    payload = {
      user_id: user.id,
      context_id: context.id,
      return_cash_transaction_id: return_transaction.id,
      investment_type_id: investment_type.id,
      observation: {
        observed_on: observed_on.iso8601,
        observed_net_cents:
      },
      calculation: calculation.except(:status, :return_cash_transaction, :investment_type_id, :observed_on),
      return_transaction: transaction_state(return_transaction),
      return_installments: return_transaction.cash_installments.sort_by(&:id).map { |installment| installment_state(installment) },
      contributions: return_transaction.piggy_bank_return_links.sort_by(&:id).map { |link| contribution_state(link) },
      valuations: return_transaction.piggy_bank_investments.sort_by(&:id).map { |investment| valuation_state(investment) }
    }

    Digest::SHA256.hexdigest(Audit::Rollback::State.canonical_json(payload))
  end

  def transaction_state(transaction)
    {
      id: transaction.id,
      user_id: transaction.user_id,
      context_id: transaction.context_id,
      user_bank_account_id: transaction.user_bank_account_id,
      cash_transaction_type: transaction.cash_transaction_type,
      date: timestamp(transaction.date),
      price: transaction.price,
      starting_price: transaction.starting_price,
      paid: transaction.paid,
      updated_at: timestamp(transaction.updated_at)
    }
  end

  def contribution_state(link)
    {
      id: link.id,
      source_cash_transaction_id: link.source_cash_transaction_id,
      return_cash_transaction_id: link.return_cash_transaction_id,
      return_date: timestamp(link.return_date),
      return_price: link.return_price,
      updated_at: timestamp(link.updated_at),
      source: transaction_state(link.source_cash_transaction),
      source_installments: link.source_cash_transaction.cash_installments.sort_by(&:id).map { |installment| installment_state(installment) }
    }
  end

  def installment_state(installment)
    {
      id: installment.id,
      cash_transaction_id: installment.cash_transaction_id,
      number: installment.number,
      date: timestamp(installment.date),
      month: installment.month,
      year: installment.year,
      price: installment.price,
      starting_price: installment.starting_price,
      paid: installment.paid,
      updated_at: timestamp(installment.updated_at)
    }
  end

  def valuation_state(investment)
    {
      id: investment.id,
      user_id: investment.user_id,
      context_id: investment.context_id,
      user_bank_account_id: investment.user_bank_account_id,
      investment_type_id: investment.investment_type_id,
      piggy_bank_return_cash_transaction_id: investment.piggy_bank_return_cash_transaction_id,
      date: timestamp(investment.date),
      month: investment.month,
      year: investment.year,
      price: investment.price,
      updated_at: timestamp(investment.updated_at)
    }
  end

  def timestamp(value)
    value&.iso8601(6)
  end

  def normalize_cents(value)
    return value if value.is_a?(Integer)
    return value.to_i if value.is_a?(String) && value.match?(/\A[1-9]\d*\z/)

    nil
  end

  def normalize_date(value)
    return value.to_date if value.respond_to?(:to_date) && !value.is_a?(String)

    Date.iso8601(value) if value.is_a?(String) && value.match?(/\A\d{4}-\d{2}-\d{2}\z/)
  rescue Date::Error
    nil
  end

  def invalid(reason_code, return_transaction: nil, issues: [])
    PiggyBankReconciliations::Plan.new(
      status: :invalid,
      reason_code:,
      return_cash_transaction: return_transaction,
      observed_on:,
      observed_net_cents:,
      issues:
    )
  end
end
