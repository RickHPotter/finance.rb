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

  # @example
  #   pretty_installments(1, 2)
  #   # => "01/02"
  #
  # @return [String]
  def pretty_installments(installment_number, installments_count)
    [ format("%02d", installment_number), format("%02d", installments_count) ].join("/")
  end

  # Generate a link to change the locale
  #
  # @return [String]
  def locale_link(locale, options = {}, &)
    path = request.path
    path_with_locale = "#{path}?locale=#{locale}"
    link_to(path_with_locale, class: options[:class], &)
  end
end
