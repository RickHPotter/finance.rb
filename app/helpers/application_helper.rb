# frozen_string_literal: true

# God Helper
module ApplicationHelper
  # Convert price from cent based (integer in the database) to float
  #
  # @return [String]
  def from_cent_based_to_float(price, currency = nil)
    price = price.to_s.rjust(3, "0").insert(-3, ".")
    price.insert(-7, ",") if price.gsub("-", "").length > 6

    [ currency, price ].compact.join(" ")
  end
end
