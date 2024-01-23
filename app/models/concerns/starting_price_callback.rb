# frozen_string_literal: true

# Shared functionality for models with audited price.
module StartingPriceCallback
  extend ActiveSupport::Concern

  included do
    # @callbacks ..............................................................
    before_validation :set_starting_price, on: :create
    before_validation :fix_price
  end

  # @public_class_methods .....................................................
  # @protected_instance_methods................................................

  protected

  # Sets `starting_price` based on the price on create.
  #
  # @note This is a method that is called before_validation.
  #
  # @return [void]
  #
  def set_starting_price
    return unless respond_to? :starting_price

    self.starting_price ||= price
  end

  # Fixes price with scale 2
  #
  # @note This is a method that is called before_validation.
  #
  # @return [void]
  #
  def fix_price
    self.price = price&.round(2)
  end
end
