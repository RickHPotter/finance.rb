# frozen_string_literal: true

# Backend Module to abstract
module Backend
  # Helper Module for Maths Operations, including Finance
  module MathsHelper
    # Calculate the prices for each installment.
    #
    # @param price [BigDecimal] The total price.
    # @param count [Integer] The number of installments to create.
    #
    # @return [Array<BigDecimal>] An array containing the prices for each installment.
    #
    def spread_installments_evenly(price, count)
      return [ price ] if count == 1

      base = (price / count.to_f).round(2)
      remainder = (base + (price - (base * count))).round(2)

      [ base ] * (count - 1) + [ remainder ]
    end
  end
end
