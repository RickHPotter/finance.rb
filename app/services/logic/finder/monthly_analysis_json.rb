# frozen_string_literal: true

class Logic::Finder::MonthlyAnalysisJson
  class InvalidMonthError < ArgumentError; end

  def initialize(user:, month:, context: user.main_context)
    @user = user
    @context = context
    @month = parse_month(month)
  end

  def call
    {
      month: @month.strftime("%Y-%m"),
      ordinary: Logic::Finder::MonthlyAnalysis::Ordinary.new(context: @context, month: @month).call,
      transfers: Logic::Finder::MonthlyAnalysis::Transfers.new(context: @context, month: @month).call,
      piggy_banks: empty_piggy_banks
    }
  end

  private

  def parse_month(value)
    match = /\A(?<year>\d{4})-(?<month>0[1-9]|1[0-2])\z/.match(value.to_s)
    raise InvalidMonthError, I18n.t("balances.monthly_analysis.invalid_month") if match.blank?

    Date.new(match[:year].to_i, match[:month].to_i, 1)
  end

  def empty_piggy_banks
    {
      total_contributed: 0.0,
      total_projected_contribution: 0.0,
      total_withdrawn: 0.0,
      total_projected_withdrawal: 0.0,
      recognized_profit_loss: 0.0,
      groups: []
    }
  end
end
