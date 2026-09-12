# frozen_string_literal: true

class Ledgers::Presenters::ExternalRow
  attr_reader :key, :kind, :description, :date, :number, :installments_count, :amount, :paid

  def self.build(installment:, kind:, share:)
    transaction = installment.public_send("#{kind}_transaction")
    date = kind == :card ? Date.new(installment.year, installment.month, 1) : installment.date
    key = Digest::SHA256.hexdigest([ share.public_id, kind, installment.id ].join(":"))

    new(
      key: "ledger_row_#{key.first(20)}",
      kind:,
      description: transaction.description,
      date:,
      number: installment.number,
      installments_count: transaction.public_send("#{kind}_installments_count"),
      amount: installment.price,
      paid: installment.paid
    )
  end

  def initialize(key:, kind:, description:, date:, number:, installments_count:, amount:, paid:)
    @key = key
    @kind = kind
    @description = description
    @date = date
    @number = number
    @installments_count = installments_count
    @amount = amount
    @paid = paid
  end

  def categories
    []
  end

  def entities
    []
  end

  def row_classes
    nil
  end

  def row_style
    nil
  end

  def internal?
    false
  end
end
