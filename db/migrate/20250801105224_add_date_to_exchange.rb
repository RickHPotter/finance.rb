# frozen_string_literal: true

class AddDateToExchange < ActiveRecord::Migration[8.0]
  def change
    return unless Exchange.table_exists?

    add_column :exchanges, :date, :datetime unless column_exists?(:exchanges, :date)
    add_column(:exchanges, :month, :integer) unless column_exists?(:exchanges, :month)
    add_column :exchanges, :year, :integer unless column_exists?(:exchanges, :year)

    Exchange.find_each do |exchange|
      cash_transaction = exchange.cash_transaction
      next if cash_transaction.nil?

      exchange.update_columns(cash_transaction.slice(:date, :month, :year))
    end

    change_column_null :exchanges, :date, false
    change_column_null :exchanges, :month, false
    change_column_null :exchanges, :year, false
  end
end
