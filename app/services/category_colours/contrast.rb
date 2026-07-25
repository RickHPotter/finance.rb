# frozen_string_literal: true

class CategoryColours::Contrast
  MINIMUM_RATIO = 4.5
  BLACK = "#000000"
  WHITE = "#ffffff"
  HEX_PATTERN = /\A#?(?<digits>[0-9a-f]{3}|[0-9a-f]{6})\z/i

  class InvalidColour < ArgumentError; end

  Assessment = Data.define(:background, :foreground, :ratio, :minimum_ratio, :suggested_foreground) do
    def passing?
      ratio >= minimum_ratio
    end

    def ratio_label
      "#{Kernel.format('%.2f', ratio)}:1"
    end
  end

  attr_reader :background

  def initialize(background)
    @background = self.class.normalize(background)
  end

  def automatic_foreground
    black_ratio = ratio_for(BLACK)
    white_ratio = ratio_for(WHITE)

    black_ratio >= white_ratio ? BLACK : WHITE
  end

  def automatic_assessment
    assess(automatic_foreground)
  end

  def assess(foreground)
    normalized_foreground = self.class.normalize(foreground)

    Assessment.new(
      background:,
      foreground: normalized_foreground,
      ratio: ratio_for(normalized_foreground),
      minimum_ratio: MINIMUM_RATIO,
      suggested_foreground: automatic_foreground
    )
  end

  def ratio_for(foreground)
    self.class.ratio(background, foreground)
  end

  class << self
    def normalize(value)
      raise InvalidColour, "colour must be a hexadecimal string" unless value.is_a?(String)

      match = HEX_PATTERN.match(value.strip)
      raise InvalidColour, "colour must contain 3 or 6 hexadecimal digits" unless match

      digits = match[:digits].downcase
      digits = digits.chars.map { |character| character * 2 }.join if digits.length == 3
      "##{digits}".freeze
    end

    def relative_luminance(value)
      red, green, blue = rgb_channels(normalize(value))
      (0.2126 * linearize(red)) + (0.7152 * linearize(green)) + (0.0722 * linearize(blue))
    end

    def ratio(first, second)
      lighter, darker = [ relative_luminance(first), relative_luminance(second) ].sort.reverse
      (lighter + 0.05) / (darker + 0.05)
    end

    private

    def rgb_channels(value)
      value.delete_prefix("#").scan(/../).map { |channel| channel.to_i(16) / 255.0 }
    end

    def linearize(channel)
      return channel / 12.92 if channel <= 0.04045

      ((channel + 0.055) / 1.055)**2.4
    end
  end
end
