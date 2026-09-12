# frozen_string_literal: true

class Ledgers::Presenters::ExternalRow
  attr_reader :key, :kind, :description, :date, :number, :installments_count, :amount, :paid, :row_classes, :row_style

  def self.build(installment:, kind:, share:)
    transaction = installment.public_send("#{kind}_transaction")
    date = kind == :card ? Date.new(installment.year, installment.month, 1) : installment.date
    key = Digest::SHA256.hexdigest([ share.public_id, kind, installment.id ].join(":"))
    presentation = category_presentation(transaction, kind:)

    new(
      key: "ledger_row_#{key.first(20)}",
      kind:,
      description: transaction.description,
      date:,
      number: installment.number,
      installments_count: transaction.public_send("#{kind}_installments_count"),
      amount: installment.price,
      paid: installment.paid,
      row_classes: presentation.row_classes,
      row_style: presentation.row_style
    )
  end

  def self.category_presentation(transaction, kind:)
    category_names = kind == :cash ? [ "EXCHANGE RETURN", "BORROW RETURN" ] : [ "EXCHANGE" ]
    categories = transaction.categories.select { |category| category.category_name.in?(category_names) }
    CategoryColours::RowPresentation.new(categories:)
  end
  private_class_method :category_presentation

  def initialize(key:, kind:, description:, date:, number:, installments_count:, amount:, paid:, row_classes:, row_style:)
    @key = key
    @kind = kind
    @description = description
    @date = date
    @number = number
    @installments_count = installments_count
    @amount = amount
    @paid = paid
    @row_classes = row_classes
    @row_style = row_style
  end

  def categories
    []
  end

  def entities
    []
  end

  def internal?
    false
  end
end
