# card_transactions = create_next_card_transactions(7022, "MENSALIDADE UNINTER", 2, 15)

def create_next_card_transactions(id, description, count, starting_number = nil)
  card_transaction = CardTransaction.find(id)
  card_transactions = []

  ref_date = Date.new(card_transaction.year, card_transaction.month)

  count.times do |index|
    new_card_transaction = card_transaction.dup
    new_ref_date = ref_date + (index + 1).months

    new_card_transaction.description = "#{description}#{" #{starting_number + index}" if starting_number}"
    new_card_transaction.date = new_card_transaction.date + (index + 1).months
    new_card_transaction.month = new_ref_date.month
    new_card_transaction.year = new_ref_date.year
    new_card_transaction.paid = false
    new_card_transaction.card_installments_count = 0
    new_card_transaction.category_transactions.build(category_id: card_transaction.category_transactions.first.category_id)
    new_card_transaction.entity_transactions.build(entity_id: card_transaction.entity_transactions.first.entity_id)

    card_installment = card_transaction.card_installments.first
    new_card_installment = card_installment.dup
    new_card_installment.card_transaction_id = new_card_transaction.id
    new_card_installment.date = new_card_transaction.date
    new_card_installment.month = new_card_transaction.month
    new_card_installment.year = new_card_transaction.year
    new_card_installment.paid = false
    new_card_transaction.card_installments = [ new_card_installment ]
    card_transactions << new_card_transaction
  end

  card_transactions
end

# cash_transactions = create_next_cash_transactions(2102, "SALARIO", 12)

def create_next_cash_transactions(id, description, count, starting_number = nil)
  cash_transaction = CashTransaction.find(id)
  cash_transactions = []

  ref_date = Date.new(cash_transaction.year, cash_transaction.month)

  count.times do |index|
    new_cash_transaction = cash_transaction.dup
    new_ref_date = ref_date + (index + 1).months

    new_cash_transaction.description = "#{description}#{" #{starting_number + index}" if starting_number}"
    new_cash_transaction.date = new_cash_transaction.date + (index + 1).months
    new_cash_transaction.month = new_ref_date.month
    new_cash_transaction.year = new_ref_date.year
    new_cash_transaction.paid = false
    new_cash_transaction.cash_installments_count = 0
    new_cash_transaction.category_transactions.build(category_id: cash_transaction.category_transactions.first.category_id)
    new_cash_transaction.entity_transactions.build(entity_id: cash_transaction.entity_transactions.first.entity_id)

    cash_installment = cash_transaction.cash_installments.first
    new_cash_installment = cash_installment.dup
    new_cash_installment.cash_transaction_id = new_cash_transaction.id
    new_cash_installment.date = new_cash_transaction.date
    new_cash_installment.month = new_cash_transaction.month
    new_cash_installment.year = new_cash_transaction.year
    new_cash_installment.paid = false
    new_cash_transaction.cash_installments = [ new_cash_installment ]
    cash_transactions << new_cash_transaction
  end

  cash_transactions
end
