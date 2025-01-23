# frozen_string_literal: true

# God Helper
module ApplicationHelper
  # Convert price from cent based (integer in the database) to float
  #
  # @return [String]
  def from_cent_based_to_float(price, currency = "")
    "#{currency} #{price.to_s.ljust(4, '0').insert(-3, '.')}"
  end
end
