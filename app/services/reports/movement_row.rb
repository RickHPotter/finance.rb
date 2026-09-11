# frozen_string_literal: true

Reports::MovementRow = Data.define(:installment, :transaction, :occurred_on, :period_key, :movement_family) do
  def identity
    [ installment_type, installment_id ]
  end

  def installment_type
    installment.class.name
  end

  def installment_id
    installment.id
  end

  def transaction_type
    transaction.class.name
  end

  def transaction_id
    transaction.id
  end

  def amount_cents
    installment.price.to_i
  end

  def starting_amount_cents
    installment.starting_price.to_i
  end

  def balance_cents
    installment.balance&.to_i
  end

  def paid?
    installment.paid?
  end

  def to_h
    {
      installment_type:,
      installment_id:,
      transaction_type:,
      transaction_id:,
      occurred_on:,
      period_key:,
      amount_cents:,
      paid: paid?,
      movement_family:
    }
  end
end
