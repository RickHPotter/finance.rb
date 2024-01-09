class Exchange < ApplicationRecord
  belongs_to :transaction_entity
  belongs_to :money_transaction
end
