# frozen_string_literal: true

class AddIofExemptOnToPiggyBanks < ActiveRecord::Migration[8.1]
  def change
    add_column :piggy_banks, :iof_exempt_on, :date
    add_index :piggy_banks, :iof_exempt_on
  end
end
