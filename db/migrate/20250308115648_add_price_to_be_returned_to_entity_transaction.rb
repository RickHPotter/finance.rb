# frozen_string_literal: true

class AddPriceToBeReturnedToEntityTransaction < ActiveRecord::Migration[8.0]
  def change
    add_column :entity_transactions, :price_to_be_returned, :integer
  end
end
