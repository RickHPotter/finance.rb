# frozen_string_literal: true

class Logic::Finder::MonthlyAnalysis::Transfers
  SENT_EXCHANGE_CATEGORY_NAME = "EXCHANGE"
  SENT_INSTALLMENT_CATEGORY_NAME = "BORROW RETURN"
  RECEIVED_INSTALLMENT_CATEGORY_NAME = "EXCHANGE RETURN"
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
    accumulator = {}
    add_installment_transfers(accumulator, cash_transfer_installments(SENT_EXCHANGE_CATEGORY_NAME), "sent")
    add_installment_transfers(accumulator, card_transfer_installments(SENT_EXCHANGE_CATEGORY_NAME), "sent")
    add_installment_transfers(accumulator, cash_transfer_installments(SENT_INSTALLMENT_CATEGORY_NAME), "sent")
    add_installment_transfers(accumulator, cash_transfer_installments(RECEIVED_INSTALLMENT_CATEGORY_NAME), "received")

    accumulator.values.sort_by { |item| [ -item[:amount], item[:entity_label], item[:direction], item[:entity_id].to_s ] }
  end

  def add_installment_transfers(accumulator, installments, direction)
    installments.each do |installment|
      bundle = entity_bundle(installment.transactable)
      bundle[:key] = "entity:#{bundle[:id]}" if bundle[:id]
      add_transfer_amount(
        accumulator,
        entity: bundle,
        direction:,
        amount: installment.price
      )
    end
  end

  def add_transfer_amount(accumulator, entity:, direction:, amount:)
    key = [ entity[:key], direction ]
    accumulator[key] ||= { entity_id: entity[:id], entity_label: entity[:label], direction:, amount: 0 }
    accumulator[key][:amount] += amount.to_i.abs
  end

  def failed_transaction_ids(relation)
    relation.joins(:categories)
            .where(categories: { category_name: FAILED_CATEGORY_NAME })
            .select(:id)
  end

  def cash_transfer_installments(category_name)
    @context.cash_installments
            .where(year: @month.year, month: @month.month)
            .joins(cash_transaction: :categories)
            .where(categories: { category_name: })
            .where.not(cash_transaction_id: failed_transaction_ids(@context.cash_transactions))
            .includes(cash_transaction: :entities)
            .distinct
            .to_a
  end

  def card_transfer_installments(category_name)
    @context.card_installments
            .where(year: @month.year, month: @month.month)
            .joins(card_transaction: :categories)
            .where(categories: { category_name: })
            .where.not(card_transaction_id: failed_transaction_ids(@context.card_transactions))
            .includes(card_transaction: :entities)
            .distinct
            .to_a
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
    if entities.empty?
      return {
        key: "entity:unassigned",
        id: nil,
        label: I18n.t("balances.monthly_analysis.unassigned")
      }
    end

    {
      key: "entities:#{entities.pluck(:id).join('+')}",
      id: entities.one? ? entities.first.id : nil,
      label: entities.map(&:name).join(" + ")
    }
  end

  def serialize_cents(amount)
    amount.fdiv(100)
  end
end
