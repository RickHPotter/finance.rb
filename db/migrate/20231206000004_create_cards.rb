# frozen_string_literal: true

# Card Migration
class CreateCards < ActiveRecord::Migration[8.0]
  def change
    create_table :cards do |t|
      t.string :card_name, null: false

      t.references :bank, null: false, foreign_key: true

      t.timestamps

      t.index [ "card_name" ], name: "index_cards_on_card_name", unique: true
    end

    Card.create(card_name: "BB", bank: Bank.find_by(bank_code: 1))
    Card.create(card_name: "MELIUZ", bank: Bank.find_by(bank_code: 1))
    Card.create(card_name: "WILL", bank: Bank.find_by(bank_code: 280))
    Card.create(card_name: "CAIXA", bank: Bank.find_by(bank_code: 104))
    Card.create(card_name: "ITAU", bank: Bank.find_by(bank_code: 341))
    Card.create(card_name: "BRADESCO", bank: Bank.find_by(bank_code: 237))
    Card.create(card_name: "SANTANDER", bank: Bank.find_by(bank_code: 33))
    Card.create(card_name: "NUBANK", bank: Bank.find_by(bank_code: 260))
    Card.create(card_name: "C6", bank: Bank.find_by(bank_code: 336))
    Card.create(card_name: "PICPAY", bank: Bank.find_by(bank_code: 380))
    Card.create(card_name: "AME", bank: Bank.find_by(bank_code: 1))
    Card.create(card_name: "NEON", bank: Bank.find_by(bank_code: 1))
    Card.create(card_name: "INTER", bank: Bank.find_by(bank_code: 77))
    Card.create(card_name: "PAN", bank: Bank.find_by(bank_code: 623))
    Card.create(card_name: "BRBR", bank: Bank.find_by(bank_code: 70))
    Card.create(card_name: "AMAZON", bank: Bank.find_by(bank_code: 237))
    Card.create(card_name: "XP", bank: Bank.find_by(bank_code: 348))
    Card.create(card_name: "RICO", bank: Bank.find_by(bank_code: 348))
    Card.create(card_name: "MERCADO PAGO", bank: Bank.find_by(bank_code: 323))
    Card.create(card_name: "PAGBANK", bank: Bank.find_by(bank_code: 290))
    Card.create(card_name: "BMG", bank: Bank.find_by(bank_code: 318))
    Card.create(card_name: "-", bank: Bank.find_by(bank_code: 0))
  end
end
