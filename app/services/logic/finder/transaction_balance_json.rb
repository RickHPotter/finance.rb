# frozen_string_literal: true

class Logic::Finder::TransactionBalanceJson
  include TranslateHelper

  def initialize(user:, month_year_one:, month_year_two:)
    month_year_two ||= month_year_one

    @user = user
    @month_year_one = month_year_one.to_datetime.beginning_of_month.beginning_of_day
    @month_year_two = month_year_two.to_datetime.end_of_month.end_of_day
  end

  def call
    return [] if items.empty?

    categories = @user.categories.map { |c| { c.category_name => c.hex_colour } }.inject(&:merge)

    items.map do |item|
      color = categories[item[:category_name]]
      category_name = item[:category_name]
      category_name = model_attribute(Category, item[:category_name].parameterize(separator: "_"), category_name).upcase

      item.slice(:type, :id).merge(
        color:,
        category_name:,
        price: item[:price].to_f / 100
      )
    end
  end

  def items
    budgets =
      @user
      .budgets
      .where("MAKE_DATE(year, month, 1) BETWEEN ? AND ?", @month_year_one, @month_year_two)
      .joins(:categories)
      .select("'budget' as type, budgets.id, remaining_value as price, categories.category_name")

    card_installments =
      @user
      .card_installments
      .where("MAKE_DATE(installments.year, installments.month, 1) BETWEEN ? AND ?", @month_year_one, @month_year_two)
      .joins(card_transaction: :categories)
      .select("'card' as type, installments.id, installments.price, categories.category_name as category_name")

    cash_installments =
      @user
      .cash_installments
      .where("MAKE_DATE(installments.year, installments.month, 1) BETWEEN ? AND ?", @month_year_one, @month_year_two)
      .joins(:cash_transaction)
      .where("cash_transactions.cash_transaction_type IS NULL or cash_transactions.cash_transaction_type <> 'CardInstallment'")
      .joins(cash_transaction: :categories)
      .select("'cash' as type, installments.id, installments.price, categories.category_name as category_name")

    (card_installments + cash_installments + budgets)
  end
end
