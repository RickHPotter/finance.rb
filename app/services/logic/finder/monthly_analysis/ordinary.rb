# frozen_string_literal: true

class Logic::Finder::MonthlyAnalysis::Ordinary
  TRANSFER_CATEGORY_NAMES = [ "EXCHANGE", "EXCHANGE RETURN", "BORROW RETURN", "FAILED LEND/BORROW RETURN" ].freeze
  PIGGY_BANK_CATEGORY_NAMES = [ "PIGGY BANK", "PIGGY BANK RETURN" ].freeze
  EXCLUDED_CASH_TRANSACTION_TYPES = %w[CardInstallment Investment PiggyBank].freeze
  NEUTRAL_COLOR = "#78716c"

  def initialize(context:, month:)
    @context = context
    @month = month
  end

  def call
    totals = ordinary_installments.each_with_object(empty_accumulator) do |installment, accumulator|
      add_installment(accumulator, installment)
    end

    {
      income: serialize_direction(totals[:income]),
      outcome: serialize_direction(totals[:outcome]),
      net: serialize_cents(totals.dig(:income, :total) - totals.dig(:outcome, :total))
    }
  end

  private

  def ordinary_installments
    (cash_installments + card_installments).select do |installment|
      ordinary_transaction?(installment.transactable)
    end
  end

  def cash_installments
    @context.cash_installments
            .where(year: @month.year, month: @month.month)
            .includes(cash_transaction: %i[categories entities])
            .to_a
  end

  def card_installments
    @context.card_installments
            .where(year: @month.year, month: @month.month)
            .includes(card_transaction: %i[categories entities])
            .to_a
  end

  def ordinary_transaction?(transaction)
    return false if transaction.is_a?(CashTransaction) && transaction.cash_transaction_type.in?(EXCLUDED_CASH_TRANSACTION_TYPES)

    category_names = transaction.categories.map(&:category_name)
    !category_names.intersect?(TRANSFER_CATEGORY_NAMES) && !category_names.intersect?(PIGGY_BANK_CATEGORY_NAMES)
  end

  def empty_accumulator
    {
      income: { total: 0, categories: {}, entities: {} },
      outcome: { total: 0, categories: {}, entities: {} }
    }
  end

  def add_installment(accumulator, installment)
    amount = installment.price.to_i
    return if amount.zero?

    direction = amount.positive? ? :income : :outcome
    magnitude = amount.abs
    transaction = installment.transactable

    accumulator[direction][:total] += magnitude
    add_bundle(accumulator[direction][:categories], category_bundle(transaction), magnitude)
    add_bundle(accumulator[direction][:entities], entity_bundle(transaction), magnitude)
  end

  def add_bundle(accumulator, bundle, amount)
    accumulator[bundle[:key]] ||= bundle.merge(amount: 0)
    accumulator[bundle[:key]][:amount] += amount
  end

  def category_bundle(transaction)
    allocations = transaction.categories.sort_by { |category| [ category.category_name, category.id ] }
    return unassigned_bundle(:category) if allocations.empty?

    {
      key: "categories:#{allocations.pluck(:id).join('+')}",
      label: allocations.map(&:name).join(" + "),
      color: allocations.one? ? (allocations.first.hex_colour || NEUTRAL_COLOR) : NEUTRAL_COLOR
    }
  end

  def entity_bundle(transaction)
    allocations = transaction.entities.sort_by { |entity| [ entity.entity_name, entity.id ] }
    return unassigned_bundle(:entity) if allocations.empty?

    {
      key: "entities:#{allocations.pluck(:id).join('+')}",
      label: allocations.map(&:name).join(" + ")
    }
  end

  def unassigned_bundle(dimension)
    {
      key: "#{dimension}:unassigned",
      label: I18n.t("balances.monthly_analysis.unassigned")
    }.tap do |bundle|
      bundle[:color] = NEUTRAL_COLOR if dimension == :category
    end
  end

  def serialize_direction(direction)
    {
      total: serialize_cents(direction[:total]),
      categories: serialize_bundles(direction[:categories]),
      entities: serialize_bundles(direction[:entities])
    }
  end

  def serialize_bundles(bundles)
    bundles.values
           .sort_by { |bundle| [ -bundle[:amount], bundle[:label], bundle[:key] ] }
           .map { |bundle| bundle.merge(amount: serialize_cents(bundle[:amount])) }
  end

  def serialize_cents(amount)
    amount.fdiv(100)
  end
end
