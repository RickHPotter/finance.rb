# frozen_string_literal: true

# CardTransaction/CashTransaction Migration
class CreateInstallments < ActiveRecord::Migration[8.0]
  def change
    create_table :installments do |t|
      t.integer :number, null: false
      t.date :date, null: false
      t.virtual "date_year", type: :integer, null: false, as: "EXTRACT(year FROM date)", stored: true
      t.virtual "date_month", type: :integer, null: false, as: "EXTRACT(month FROM date)", stored: true
      t.integer :month, null: false
      t.integer :year, null: false
      t.integer :starting_price, null: false
      t.integer :price, null: false
      t.boolean :paid, default: false
      t.string :installment_type, null: false
      t.integer :card_installments_count, default: 0, null: true
      t.integer :cash_installments_count, default: 0, null: true

      t.references :card_transaction, null: true, foreign_key: true
      t.references :cash_transaction, null: true, foreign_key: true

      t.timestamps

      t.index [ :price ],               name: "idx_installments_price"
      t.index %i[date_year date_month], name: "idx_installments_year_month"
    end
  end
end
