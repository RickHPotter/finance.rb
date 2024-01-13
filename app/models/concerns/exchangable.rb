# frozen_string_literal: true

# Shared functionality for models that can produce Exchanges.
module Exchangable
  extend ActiveSupport::Concern

  included do
    # @security (i.e. attr_accessible) ........................................
    attr_accessor :exchange_attributes

    # @relationships ..........................................................
    has_many :exchanges

    # @callbacks ..............................................................
    before_save :create_exchanges
  end

  # @protected_instance_methods ...............................................

  protected

  def create_exchanges
    return if exchange_attributes.blank? || persisted?

    exchange_attributes.each_with_index do |attributes, index|
      exchanges << Exchange.create(attributes.merge(number: index + 1))
    end
  end
end
