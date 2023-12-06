# frozen_string_literal: true

# Shared functionality for models with audited price.
module StartingPriceCallback
  extend ActiveSupport::Concern

  included do
    before_validation :set_starting_price, on: :create
  end

  # @protected_instance_methods................................................

  protected

  # Sets starting_price based on the price on create.
  #
  # @note This is a callback that is called before_create.
  #
  # @return [void]
  def set_starting_price
    self.starting_price ||= price
  end
end
