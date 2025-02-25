# frozen_string_literal: true

# God Helper
module ApplicationHelper
  # Convert price from cent based (integer in the database) to float
  #
  # @return [String]
  def from_cent_based_to_float(price, currency = nil)
    price = price.to_s
    negative = price.starts_with?("-")

    price = price.delete("-").rjust(3, "0")
    price.insert(-3, ".") if price.length > 2
    price.insert(-7, ",") if price.length > 6

    price = "-#{price}" if negative

    [ currency, price ].compact.join(" ")
  end
end
