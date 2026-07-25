# frozen_string_literal: true

module ColoursHelper
  def auto_text_color(hex)
    foreground = CategoryColours::Contrast.new(hex).automatic_foreground
    "color: #{foreground};"
  rescue CategoryColours::Contrast::InvalidColour
    "color: #000000;"
  end

  def solid_or_gradient_style(categories)
    CategoryColours::Presentation.bundle(categories).combined.inline_style
  end
end
