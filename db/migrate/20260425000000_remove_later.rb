# frozen_string_literal: true

class RemoveLater < ActiveRecord::Migration[8.0]
  def change
    fix_lack_of_moi
    fix_card_transaction(card_transaction_id: 8498)
    fix_card_transaction_7832
    rikki_rec.call
  end

  def fix_lack_of_moi
    moi = User.first.entities.find_by(entity_name: "MOI")
    CardTransaction.where(id: [ 4094, 7452, 7832 ]).find_each do |card_transaction|
      used_price = card_transaction.entity_transactions.sum(:price)
      new_moi_price = card_transaction.price.abs - used_price

      if card_transaction.entity_transactions.find_by(entity_id: moi.id)
        card_transaction.entity_transactions.find_by(entity_id: moi.id).update(price: new_moi_price)
      else
        card_transaction.entity_transactions.create(is_payer: false, entity_id: moi.id, price: new_moi_price)
      end
    end
  end

  def fix_card_transaction(card_transaction_id:)
    april_return_id = 4962
    may_return_id = 4963

    card = CardTransaction.includes(:card_installments, entity_transactions: :exchanges).find(card_transaction_id)
    payer = card.entity_transactions.find_by!(is_payer: true)

    april_return = CashTransaction.includes(:cash_installments, :exchanges).find(april_return_id)
    may_return = CashTransaction.includes(:cash_installments, :exchanges).find(may_return_id)

    desired_rows = [
      {
        number: 1,
        cash_transaction_id: april_return.id,
        date: april_return.date,
        month: 4,
        year: 2026,
        price: 6_717
      },
      {
        number: 2,
        cash_transaction_id: may_return.id,
        date: may_return.date,
        month: 5,
        year: 2026,
        price: 6_717
      }
    ]

    puts "Before:"
    puts({
      card_id: card.id,
      card_price: card.price,
      payer_id: payer.id,
      payer_price: payer.price,
      payer_price_to_be_returned: payer.price_to_be_returned,
      exchanges: payer.exchanges.order(:number, :id).map do |e|
        {
          id: e.id,
          cash_transaction_id: e.cash_transaction_id,
          number: e.number,
          price: e.price,
          month: e.month,
          year: e.year
        }
      end,
      may_return_price: may_return.price,
      may_return_exchange_sum: may_return.exchanges.sum(:price)
    }.inspect)

    now = Time.current
    existing = payer.exchanges.monetary.order(:number, :id).to_a

    desired_rows.each_with_index do |row, index|
      exchange = existing[index]

      attrs = {
        entity_transaction_id: payer.id,
        cash_transaction_id: row[:cash_transaction_id],
        bound_type: "card_bound",
        exchange_type: Exchange.exchange_types.fetch(:monetary),
        number: row[:number],
        date: row[:date],
        month: row[:month],
        year: row[:year],
        price: row[:price],
        starting_price: row[:price],
        exchanges_count: 2,
        updated_at: now
      }

      if exchange
        exchange.update_columns(attrs)
      else
        Exchange.insert(attrs.merge(created_at: now))
      end
    end

    extra_ids = existing.drop(desired_rows.size).map(&:id)
    Exchange.where(id: extra_ids).delete_all if extra_ids.any?

    payer.update_columns(
      price: 13_434,
      price_to_be_returned: 13_434,
      exchanges_count: 2,
      updated_at: now
    )
    payer.exchanges.update_all(exchanges_count: 2, updated_at: now)

    may_total = may_return.reload.exchanges.sum(:price)
    may_return.update_columns(price: may_total, starting_price: may_total, updated_at: now)

    if may_return.cash_installments.where(paid: true).none? && may_return.cash_installments.one?
      installment = may_return.cash_installments.first
      installment.update_columns(price: may_total, starting_price: may_total, updated_at: now)
    end

    puts "After:"
    puts({
      payer_price: payer.reload.price,
      payer_price_to_be_returned: payer.price_to_be_returned,
      exchanges: payer.exchanges.order(:number, :id).map do |e|
        {
          id: e.id,
          cash_transaction_id: e.cash_transaction_id,
          number: e.number,
          price: e.price,
          month: e.month,
          year: e.year
        }
      end,
      may_return_price: may_return.reload.price,
      may_return_exchange_sum: may_return.exchanges.sum(:price)
    }.inspect)
  end

  def fix_card_transaction_7832
    card = CardTransaction.includes(:card_installments, entity_transactions: %i[entity exchanges]).find(7832)
    lala_entity_transaction = card.entity_transactions.joins(:entity).find_by!(entities: { entity_name: "LALA" })
    moi = card.user.entities.find_by!(entity_name: "MOI")
    moi_entity_transaction = card.entity_transactions.find_by(entity_id: moi.id) || card.entity_transactions.create!(entity: moi, is_payer: false, price: 0,
                                                                                                                       price_to_be_returned: 0)

    desired_descriptions = [
      "[ 02/2026 ] LALA - WILL",
      "[ 03/2026 ] LALA - WILL",
      "[ 04/2026 ] LALA - WILL",
      "[ 05/2026 ] LALA - WILL",
      "[ 06/2026 ] LALA - WILL",
      "[ 07/2026 ] LALA - WILL",
      "[ 08/2026 ] LALA - WILL",
      "[ 09/2026 ] LALA - WILL",
      "[ 10/2026 ] LALA - WILL",
      "[ 11/2026 ] LALA - WILL"
    ]

    desired_cash_transactions = desired_descriptions.map do |description|
      card.context.cash_transactions.exchange_return.find_by!(description:)
    end

    desired_rows = desired_cash_transactions.each_with_index.map do |cash_transaction, index|
      installment_date = cash_transaction.cash_installments.order(:number, :date).first&.date || cash_transaction.date

      {
        number: index + 1,
        cash_transaction_id: cash_transaction.id,
        date: installment_date,
        month: cash_transaction.month,
        year: cash_transaction.year,
        price: 19_151
      }
    end

    puts "Before 7832:"
    puts({
      card_id: card.id,
      card_price: card.price,
      lala_entity_transaction_id: lala_entity_transaction.id,
      lala_price: lala_entity_transaction.price,
      lala_price_to_be_returned: lala_entity_transaction.price_to_be_returned,
      moi_entity_transaction_id: moi_entity_transaction.id,
      moi_price: moi_entity_transaction.price,
      lala_exchanges: lala_entity_transaction.exchanges.order(:number, :id).map do |exchange|
        {
          id: exchange.id,
          cash_transaction_id: exchange.cash_transaction_id,
          number: exchange.number,
          price: exchange.price,
          month: exchange.month,
          year: exchange.year
        }
      end
    }.inspect)

    now = Time.current
    existing = lala_entity_transaction.exchanges.monetary.order(:number, :id).to_a

    desired_rows.each_with_index do |row, index|
      exchange = existing[index]
      attrs = {
        entity_transaction_id: lala_entity_transaction.id,
        cash_transaction_id: row[:cash_transaction_id],
        bound_type: "card_bound",
        exchange_type: Exchange.exchange_types.fetch(:monetary),
        number: row[:number],
        date: row[:date],
        month: row[:month],
        year: row[:year],
        price: row[:price],
        starting_price: row[:price],
        exchanges_count: desired_rows.size,
        updated_at: now
      }

      if exchange.present?
        exchange.update_columns(attrs)
      else
        Exchange.insert(attrs.merge(created_at: now))
      end
    end

    extra_ids = existing.drop(desired_rows.size).map(&:id)
    Exchange.where(id: extra_ids).delete_all if extra_ids.any?

    lala_total = desired_rows.sum { |row| row[:price] }
    moi_total = card.price.abs - lala_total

    lala_entity_transaction.update_columns(
      price: lala_total,
      price_to_be_returned: lala_total,
      exchanges_count: desired_rows.size,
      updated_at: now
    )
    lala_entity_transaction.exchanges.update_all(exchanges_count: desired_rows.size, updated_at: now)

    moi_entity_transaction.update_columns(
      price: moi_total,
      price_to_be_returned: 0,
      is_payer: false,
      updated_at: now
    )

    puts "After 7832:"
    puts({
      lala_price: lala_entity_transaction.reload.price,
      lala_price_to_be_returned: lala_entity_transaction.price_to_be_returned,
      moi_price: moi_entity_transaction.reload.price,
      lala_exchanges: lala_entity_transaction.exchanges.order(:number, :id).map do |exchange|
        {
          id: exchange.id,
          cash_transaction_id: exchange.cash_transaction_id,
          number: exchange.number,
          price: exchange.price,
          month: exchange.month,
          year: exchange.year
        }
      end
    }.inspect)
  end
end
