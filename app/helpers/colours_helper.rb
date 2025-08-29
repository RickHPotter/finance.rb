# frozen_string_literal: true

module ColoursHelper
  def auto_text_color(hex) # rubocop:disable Metrics/AbcSize
    h = hex.to_s.delete_prefix("#")
    h = h.chars.map { |c| c * 2 }.join if h.length == 3
    return "#000000" unless h.match?(/\A[0-9a-fA-F]{6}\z/)

    r = h[0, 2].to_i(16) / 255.0
    g = h[2, 2].to_i(16) / 255.0
    b = h[4, 2].to_i(16) / 255.0
    lin = [ r, g, b ].map { |v| v <= 0.03928 ? v / 12.92 : ((v + 0.055) / 1.055)**2.4 }
    l = (0.2126 * lin[0]) + (0.7152 * lin[1]) + (0.0722 * lin[2])
    contrast_white = 1.05 / (l + 0.05)
    contrast_black = (l + 0.05) / 0.05
    hex_colour = contrast_black >= contrast_white ? "#000000" : "#ffffff"

    "color: #{hex_colour};"
  end

  def linear_gradient_css(colours)
    colours.map! do |s|
      if s.is_a?(Hash)
        s[:color]
      else
        s
      end
    end

    "linear-gradient(to right, #{colours.join(', ')})"
  end

  def solid_or_gradient_style(categories)
    categories = [ categories ] if categories.is_a?(Category)

    if categories.size > 1
      colours = categories.map do |category|
        { color: category.hex_colour }
      end

      "background-image: #{linear_gradient_css(colours)};"
    else
      hex = categories.first&.hex_colour || "#000000"
      "background-color: #{hex};"
    end
  end
end
