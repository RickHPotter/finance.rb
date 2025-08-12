# frozen_string_literal: true

# Shared functionality for models with audited price.
module HasStartingPrice
  extend ActiveSupport::Concern

  included do
    # @callbacks ..............................................................
    before_validation :set_starting_price, on: :create

    # @validations ..............................................................
    validates :starting_price, :price, presence: true
    validates :paid, inclusion: { in: [ true, false ] }, if: -> { defined? paid }
  end

  # @public_class_methods .....................................................
  # @protected_instance_methods................................................

  protected

  # Sets `starting_price` based on the `price` on create.
  #
  # @note This is a method that is called before_validation.
  #
  # @return [void].
  #
  def set_starting_price
    return unless respond_to? :starting_price

    self.starting_price ||= price
  end
end
