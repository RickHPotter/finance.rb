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
    add_installment_transfers(accumulator, cash_transfer_installments(SENT_EXCHANGE_CATEGORY_NAME), "sent", :exchange)
    add_installment_transfers(accumulator, card_transfer_installments(SENT_EXCHANGE_CATEGORY_NAME), "sent", :exchange)
    add_installment_transfers(accumulator, cash_transfer_installments(SENT_INSTALLMENT_CATEGORY_NAME), "sent", :borrow_return)
    add_installment_transfers(accumulator, cash_transfer_installments(RECEIVED_INSTALLMENT_CATEGORY_NAME), "received", :exchange_return)

    accumulator.values.sort_by { |item| [ -item[:amount], item[:entity_label], item[:direction], item[:entity_id].to_s ] }
  end

  def add_installment_transfers(accumulator, installments, direction, role)
    installments.each do |installment|
      bundle = entity_bundle(installment.transactable)
      bundle[:key] = "entity:#{bundle[:id]}" if bundle[:id]
      add_transfer_amount(
        accumulator,
        entity: bundle,
        direction:,
        amount: installment.price,
        source: transfer_source(installment, role)
      )
    end
  end

  def add_transfer_amount(accumulator, entity:, direction:, amount:, source:)
    key = [ entity[:key], direction ]
    accumulator[key] ||= { entity_id: entity[:id], entity_label: entity[:label], direction:, amount: 0, sources: [] }
    accumulator[key][:amount] += amount.to_i.abs
    accumulator[key][:sources] << source
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
    accumulator = failed_installments.each_with_object({}) { |installment, result| add_failed_transfer(result, installment) }

    accumulator.values
               .sort_by { |item| [ -item[:amount], item[:entity_label], item[:key] ] }
               .map { |item| item.merge(amount: serialize_cents(item[:amount])) }
  end

  def add_failed_transfer(accumulator, installment)
    bundle = entity_bundle(installment.cash_transaction)
    accumulator[bundle[:key]] ||= failed_transfer_group(bundle)
    accumulator[bundle[:key]][:amount] += installment.starting_price.to_i.abs
    accumulator[bundle[:key]][:sources] << source_navigation(
      installment,
      :failed_return,
      return_origin(installment),
      amount_cents: installment.starting_price.to_i.abs
    )
  end

  def failed_transfer_group(bundle)
    {
      key: bundle[:key],
      entity_label: bundle[:label],
      amount: 0,
      state: "failed",
      amount_source: "starting_price",
      sources: []
    }
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

  def transfer_source(installment, role)
    origin = role == :exchange ? :source : return_origin(installment)

    source_navigation(installment, role, origin, amount_cents: installment.price.to_i.abs)
  end

  def return_origin(installment)
    installment.transactable.reference_transactable_id.present? ? :generated_return : :return
  end

  def source_navigation(installment, role, origin, amount_cents:)
    Reports::SourceNavigation.new(
      record: installment.transactable,
      installment:,
      role:,
      origin:,
      amount_cents:,
      return_to: analysis_return_path
    ).call
  end

  def analysis_return_path
    @analysis_return_path ||= Rails.application.routes.url_helpers.balances_path(tab: "monthly_analysis", month: @month.strftime("%Y-%m"))
  end

  def serialize_cents(amount)
    amount.fdiv(100)
  end
end
