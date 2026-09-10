# frozen_string_literal: true

class Logic::Finder::MonthlyAnalysis::PiggyBanks
  TOTAL_FIELDS = %i[contributed projected_contribution withdrawn projected_withdrawal recognized_profit_loss].freeze

  def initialize(context:, month:)
    @context = context
    @month = month
  end

  def call
    groups = build_groups

    {
      total_contributed: serialize_cents(sum_field(groups, :contributed)),
      total_projected_contribution: serialize_cents(sum_field(groups, :projected_contribution)),
      total_withdrawn: serialize_cents(sum_field(groups, :withdrawn)),
      total_projected_withdrawal: serialize_cents(sum_field(groups, :projected_withdrawal)),
      recognized_profit_loss: serialize_cents(sum_field(groups, :recognized_profit_loss)),
      groups: serialize_groups(groups)
    }
  end

  private

  def build_groups
    {}.tap do |groups|
      contribution_installments.each { |installment| add_contribution(groups, installment) }
      withdrawal_installments.each { |installment| add_withdrawal(groups, installment) }
      valuations.each { |investment| add_valuation(groups, investment) }
    end
  end

  def contribution_installments
    @context.cash_installments
            .where(year: @month.year, month: @month.month)
            .joins(cash_transaction: :piggy_bank)
            .includes(cash_transaction: { piggy_bank: :return_cash_transaction })
            .distinct
            .to_a
  end

  def withdrawal_installments
    @context.cash_installments
            .where(year: @month.year, month: @month.month)
            .joins(cash_transaction: :piggy_bank_return_links)
            .where(cash_transactions: { cash_transaction_type: "PiggyBank" })
            .includes(:cash_transaction)
            .distinct
            .to_a
  end

  def valuations
    @context.investments
            .where(year: @month.year, month: @month.month)
            .where.not(piggy_bank_return_cash_transaction_id: nil)
            .includes(:piggy_bank_return_cash_transaction)
            .to_a
  end

  def add_contribution(groups, installment)
    return_transaction = installment.cash_transaction.piggy_bank&.return_cash_transaction
    return if return_transaction.blank?

    field = installment.paid? ? :contributed : :projected_contribution
    group = group_for(groups, return_transaction)
    group[field] += installment.price.to_i.abs
    group[:sources][field] << source_navigation(
      installment.cash_transaction,
      installment:,
      role: field,
      origin: :source,
      amount_cents: installment.price.to_i.abs
    )
  end

  def add_withdrawal(groups, installment)
    field = installment.paid? ? :withdrawn : :projected_withdrawal
    group = group_for(groups, installment.cash_transaction)
    group[field] += installment.price.to_i.abs
    group[:sources][field] << source_navigation(
      installment.cash_transaction,
      installment:,
      role: field,
      origin: :generated_return,
      amount_cents: installment.price.to_i.abs
    )
  end

  def add_valuation(groups, investment)
    return_transaction = investment.piggy_bank_return_cash_transaction
    return if return_transaction.blank?

    group = group_for(groups, return_transaction)
    group[:recognized_profit_loss] += investment.price.to_i
    group[:sources][:recognized_profit_loss] << source_navigation(investment, role: :valuation, origin: :valuation, amount_cents: investment.price.to_i)
  end

  def group_for(groups, return_transaction)
    groups[return_transaction.id] ||= {
      return_cash_transaction_id: return_transaction.id,
      return_identity: { record_type: return_transaction.class.name, record_id: return_transaction.id },
      return_path: source_navigation(return_transaction, role: :piggy_bank_return, origin: :generated_return).fetch(:path),
      label: return_transaction.description,
      contributed: 0,
      projected_contribution: 0,
      withdrawn: 0,
      projected_withdrawal: 0,
      recognized_profit_loss: 0,
      sources: TOTAL_FIELDS.index_with { [] }
    }
  end

  def sum_field(groups, field)
    groups.values.sum { |group| group[field] }
  end

  def serialize_groups(groups)
    groups.values
          .sort_by { |group| [ group[:label], group[:return_cash_transaction_id] ] }
          .map do |group|
      group.merge(TOTAL_FIELDS.to_h { |field| [ field, serialize_cents(group[field]) ] })
    end
  end

  def serialize_cents(amount)
    amount.fdiv(100)
  end

  def source_navigation(record, role:, origin:, installment: nil, amount_cents: nil)
    Reports::SourceNavigation.new(record:, installment:, role:, origin:, amount_cents:, return_to: analysis_return_path).call
  end

  def analysis_return_path
    @analysis_return_path ||= Rails.application.routes.url_helpers.balances_path(tab: "monthly_analysis", month: @month.strftime("%Y-%m"))
  end
end
