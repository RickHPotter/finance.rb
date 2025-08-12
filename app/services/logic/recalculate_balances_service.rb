# frozen_string_literal: true

module Logic
  class RecalculateBalancesService
    def initialize(user:, year:, month:)
      @user = user
      @year = year
      @month = month
    end

    def call
      set_order_and_balance
      set_items

      apply_balances
    end

    private

    def set_order_and_balance
      @date_threshold = Date.new(@year, @month, 1)

      @past_budget           = @user.budgets.where("year < ? OR (year = ? AND month < ?)", @year, @year, @month).order(:order_id).last
      @past_cash_installment = @user.cash_installments
                                    .where("installments.date < ?", @date_threshold)
                                    .where("make_date(installments.year, installments.month, 1) < make_date(#{@year}, #{@month}, 1)")
                                    .order(:order_id).last

      @running_balance = @past_budget&.balance || @past_cash_installment&.balance || 0
      @next_order_id   = [ @past_cash_installment&.order_id, @past_budget&.order_id, -1 ].compact.max
    end

    def set_items
      @cash_installments =
        @user.cash_installments
             .where(
               "installments.date >= :date
               OR (installments.year > :year OR (installments.year = :year AND installments.month >= :month))",
               date: @date_threshold,
               year: @year, month: @month
             )
             .order(:order_id)
             .select("*", :id, :date, :price, :cash_transaction_id, :year, :month, "cash_transactions.cash_transaction_type")

      @budgets =
        @user.budgets
             .where("year > ? OR (year = ? AND month >= ?)", @year, @year, @month)
             .order(:order_id)
             .select("*", :id, :year, :month, "'Budget' AS cash_transaction_type", "make_date(year, month, 1) AS date", remaining_value: :price)

      @items = (@cash_installments + @budgets).sort_by { |i| sort_key(i) }
    end

    def apply_balances
      cash_installments = []
      budgets = []

      @items.each do |item|
        @running_balance += item.price
        @next_order_id += 1

        item.assign_attributes(balance: @running_balance, order_id: @next_order_id)

        if item.cash_transaction_type == "Budget"
          budgets << item
        else
          cash_installments << item
        end
      end

      on_duplicate_key_update = { conflict_target: [ :id ], columns: %i[balance order_id] }
      CashInstallment.import(cash_installments, on_duplicate_key_update:)
      Budget.import(budgets, on_duplicate_key_update:)
    end

    def sort_key(item)
      [
        item.year,
        item.month,
        case item.cash_transaction_type
        when "Investment" then 0
        when "Budget" then 2
        else 1
        end,
        item.date,
        item.price * -1,
        item.id
      ]
    end
  end
end
