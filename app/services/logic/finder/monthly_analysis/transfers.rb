# frozen_string_literal: true

class Logic::Finder::MonthlyAnalysis::Transfers
  MONETARY_CATEGORY_NAMES = [ "EXCHANGE", "EXCHANGE RETURN", "BORROW RETURN" ].freeze
  FAILED_CATEGORY_NAME = "FAILED LEND/BORROW RETURN"

  def initialize(context:, month:)
    @context = context
    @month = month
  end

  def call
    items = transfer_items

    {
      total_sent: serialize_cents(items.sum { |item| item[:direction] == "sent" ? item[:amount] : 0 }),
      total_received: serialize_cents(items.sum { |item| item[:direction] == "received" ? item[:amount] : 0 }),
      items: items.map { |item| item.merge(amount: serialize_cents(item[:amount])) },
      failed: failed_transfer_items
    }
  end

  private

  def transfer_items
    accumulator = transfer_exchanges.each_with_object({}) do |exchange, result|
      entity_transaction = exchange.entity_transaction
      direction = entity_transaction.is_payer? ? "sent" : "received"
      key = [ entity_transaction.entity_id, direction ]
      result[key] ||= {
        entity_id: entity_transaction.entity_id,
        entity_label: entity_transaction.entity.name,
        direction:,
        amount: 0
      }
      result[key][:amount] += exchange.price.to_i.abs
    end

    accumulator.values.sort_by { |item| [ -item[:amount], item[:entity_label], item[:direction], item[:entity_id] ] }
  end

  def transfer_exchanges
    exchanges = transfer_exchanges_for("CashTransaction", transfer_cash_transaction_ids) +
                transfer_exchanges_for("CardTransaction", transfer_card_transaction_ids)
    exchanges.index_by(&:id).values
  end

  def transfer_exchanges_for(transactable_type, transactable_ids)
    return [] if transactable_ids.empty?

    Exchange.monetary
            .where(year: @month.year, month: @month.month)
            .joins(:entity_transaction)
            .where(entity_transactions: { transactable_type:, transactable_id: transactable_ids })
            .includes(entity_transaction: :entity)
            .to_a
  end

  def transfer_cash_transaction_ids
    @transfer_cash_transaction_ids ||= transfer_transaction_ids(@context.cash_transactions)
  end

  def transfer_card_transaction_ids
    @transfer_card_transaction_ids ||= transfer_transaction_ids(@context.card_transactions)
  end

  def transfer_transaction_ids(relation)
    relation.joins(:categories)
            .where(categories: { category_name: MONETARY_CATEGORY_NAMES })
            .distinct
            .ids
  end

  def failed_transfer_items
    accumulator = failed_installments.each_with_object({}) do |installment, result|
      bundle = entity_bundle(installment.cash_transaction)
      result[bundle[:key]] ||= {
        key: bundle[:key],
        entity_label: bundle[:label],
        amount: 0,
        state: "failed",
        amount_source: "starting_price"
      }
      result[bundle[:key]][:amount] += installment.starting_price.to_i.abs
    end

    accumulator.values
               .sort_by { |item| [ -item[:amount], item[:entity_label], item[:key] ] }
               .map { |item| item.merge(amount: serialize_cents(item[:amount])) }
  end

  def failed_installments
    @context.cash_installments
            .where(year: @month.year, month: @month.month)
            .joins(cash_transaction: :categories)
            .where(categories: { category_name: FAILED_CATEGORY_NAME })
            .includes(cash_transaction: :entities)
            .distinct
            .to_a
  end

  def entity_bundle(transaction)
    entities = transaction.entities.sort_by { |entity| [ entity.entity_name, entity.id ] }
    return { key: "entity:unassigned", label: I18n.t("balances.monthly_analysis.unassigned") } if entities.empty?

    {
      key: "entities:#{entities.pluck(:id).join('+')}",
      label: entities.map(&:name).join(" + ")
    }
  end

  def serialize_cents(amount)
    amount.fdiv(100)
  end
end
