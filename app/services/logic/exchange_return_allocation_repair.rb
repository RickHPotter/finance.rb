# frozen_string_literal: true

class Logic::ExchangeReturnAllocationRepair
  ALLOWED_ATTRIBUTES = %w[loan_return_percentage price price_to_be_returned].freeze

  attr_reader :attributes, :entity_transaction

  def initialize(entity_transaction:, attributes:)
    @entity_transaction = entity_transaction
    @attributes = attributes.to_h.stringify_keys.slice(*ALLOWED_ATTRIBUTES)
  end

  def call
    raise ArgumentError, "allocation repair has no changes" if attributes.empty?

    entity_transaction.update!(attributes)
    entity_transaction
  end
end
