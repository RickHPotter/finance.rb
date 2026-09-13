# frozen_string_literal: true

class Ledgers::Presenters::InternalRow
  attr_reader :key, :kind, :description, :date, :number, :installments_count, :amount, :paid,
              :categories, :entities, :row_classes, :row_style

  def initialize(installment:, kind:, category_colour_display_mode: CategoryColours::DisplayMode::DEFAULT)
    transaction = installment.public_send("#{kind}_transaction")
    ordered_categories = CategoryColours::Ordering.from_allocations(transaction.category_transactions)
    presentation = CategoryColours::RowPresentation.new(categories: ordered_categories, mode: category_colour_display_mode)

    @key = "#{kind}_installment_#{installment.id}"
    @kind = kind
    @description = transaction.description
    @date = display_date(installment)
    @number = installment.number
    @installments_count = transaction.public_send("#{kind}_installments_count")
    @amount = installment.price
    @paid = installment.paid
    @categories = ordered_categories
    @entities = transaction.entity_transactions.sort_by(&:id).filter_map do |allocation|
      entity = allocation.entity
      Ledgers::Presenters::Entity.new(name: entity.entity_name, avatar_name: entity.avatar_name) if entity
    end
    @row_classes = presentation.row_classes
    @row_style = presentation.row_style
  end

  def internal?
    true
  end

  private

  def display_date(installment)
    return Date.new(installment.year, installment.month, 1) if kind == :card

    installment.date
  end
end
