# frozen_string_literal: true

class Logic::MonthlyBalanceBuilder
  def initialize(user:)
    @user = user
  end

  def call # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
    return [] if items.empty?

    raw_data = items.each_with_object(Hash.new { |h, k| h[k] = [] }) do |dt, h|
      h[[ dt.year, dt.month ]] << (dt.balance.to_f / 100)
    end

    first_date = Date.new(*raw_data.keys.min)
    last_date  = Date.new(*raw_data.keys.max)

    result = []
    current_date = first_date
    last_balance = 0

    x = 0

    while current_date <= last_date
      ym_key = [ current_date.year, current_date.month ]
      balances = raw_data[ym_key]

      if balances.present?
        balances.each do |balance|
          result << {
            x: x,
            y: balance,
            label: current_date.strftime("%b").upcase + " <#{current_date.strftime('%y')}>",
            raw_month_year: current_date.strftime("%Y%m").to_i
          }
          last_balance = balance
          x += 1
        end
      else
        result << {
          x:,
          y: last_balance,
          label: current_date.strftime("%b").upcase + " <#{current_date.strftime('%y')}>",
          raw_month_year: current_date.strftime("%Y%m").to_i
        }
        x += 1
      end

      current_date = current_date.next_month
    end

    result
  end

  def items
    cash_installments = @user.cash_installments
    budgets = @user.budgets

    (cash_installments + budgets).sort_by(&:order_id)
  end
end
