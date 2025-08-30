# frozen_string_literal: true

module ColoursHelper
  def auto_text_color(hex)
    h = hex.to_s.delete_prefix("#")
    h = h.chars.map { |c| c * 2 }.join if h.length == 3
    return "color: #000000;" unless h.match?(/\A[0-9a-fA-F]{6}\z/)

    bg_rgb = hex_to_rgb(h)

    gray_candidates = (0..255).step(16).map do |v|
      [ v, v, v ]
    end

    best_contrast = 0
    best_color = [ 0, 0, 0 ]

    gray_candidates.each do |gray_rgb|
      contrast = wcag_contrast_ratio(bg_rgb, gray_rgb)
      if contrast > best_contrast
        best_contrast = contrast
        best_color = gray_rgb
      end
    end

    hex_color = rgb_to_hex(best_color)
    "color: #{hex_color};"
  end

  def hex_to_rgb(hex)
    [
      hex[0, 2].to_i(16),
      hex[2, 2].to_i(16),
      hex[4, 2].to_i(16)
    ]
  end

  def rgb_to_hex(rgb)
    "#" + rgb.map { |v| v.to_s(16).rjust(2, "0") }.join
  end

  def relative_luminance(rgb)
    r, g, b = rgb.map { |c| c / 255.0 }
    r = r <= 0.03928 ? r / 12.92 : ((r + 0.055) / 1.055)**2.4
    g = g <= 0.03928 ? g / 12.92 : ((g + 0.055) / 1.055)**2.4
    b = b <= 0.03928 ? b / 12.92 : ((b + 0.055) / 1.055)**2.4
    (0.2126 * r) + (0.7152 * g) + (0.0722 * b)
  end

  def wcag_contrast_ratio(rgb1, rgb2)
    l1 = relative_luminance(rgb1)
    l2 = relative_luminance(rgb2)
    l1, l2 = [ l1, l2 ].sort.reverse
    (l1 + 0.05) / (l2 + 0.05)
  end

  def linear_gradient_css(colours)
    colours.map! do |s|
      if s.is_a?(Hash)
        s[:colour]
      else
        s
      end
    end

    "linear-gradient(to right, #{colours.join(', ')})"
  end

  def solid_or_gradient_style(categories)
    categories = [ categories ] if categories.is_a?(Category)

    return "background-color: #FFFFFF; #000000}" if categories.empty?

    bg_hex = categories.first.hex_colour || "#000000"
    text_hex = auto_text_color(bg_hex)
    return "background-color: #{bg_hex}; #{text_hex}" if categories.size == 1

    colours = categories.map do |category|
      { colour: category.hex_colour }
    end

    "background-image: #{linear_gradient_css(colours)}; #{text_hex}"
  end
end
