# frozen_string_literal: true

class CategoryColours::Presentation
  NEUTRAL_BACKGROUND = "#e2e8f0"
  NEUTRAL_FOREGROUND = "#0f172a"
  FOCUS_INNER = "#ffffff"
  FOCUS_OUTER = "#000000"

  class InaccessiblePair < ArgumentError; end

  Segment = Data.define(:key, :label, :presentation) do
    def chart_payload
      presentation.chart_payload.merge(id: key, label:)
    end
  end

  Bundle = Data.define(:segments, :combined, :label) do
    def empty?
      segments.empty?
    end

    def multiple?
      segments.many?
    end

    def chart_payload
      combined.chart_payload.merge(segments: segments.map(&:chart_payload))
    end
  end

  attr_reader :background, :foreground, :contrast_ratio, :border_colour, :focus_inner, :focus_outer

  def self.for(category)
    return neutral if category.nil?

    new(background: category.hex_colour, foreground: category.resolved_text_colour)
  rescue CategoryColours::Contrast::InvalidColour, InaccessiblePair
    neutral
  end

  def self.bundle(categories)
    unique_categories = Array(categories).compact.uniq { |category| [ category.class.name, category.id || category.object_id ] }
    segments = unique_categories.map do |category|
      Segment.new(
        key: category.id || category.object_id,
        label: category.name.to_s.dup.freeze,
        presentation: self.for(category)
      )
    end.freeze

    combined = segments.one? ? segments.first.presentation : neutral
    Bundle.new(segments:, combined:, label: segments.map(&:label).join(" + ").freeze)
  end

  def self.neutral
    @neutral ||= new(background: NEUTRAL_BACKGROUND, foreground: NEUTRAL_FOREGROUND, fallback: true)
  end

  def initialize(background:, foreground:, fallback: false)
    contrast = CategoryColours::Contrast.new(background)
    assessment = contrast.assess(foreground)
    raise InaccessiblePair, "category colour pair must meet #{CategoryColours::Contrast::MINIMUM_RATIO}:1" unless assessment.passing?

    @background = assessment.background
    @foreground = assessment.foreground
    @contrast_ratio = assessment.ratio
    @border_colour = assessment.foreground
    @focus_inner = FOCUS_INNER
    @focus_outer = FOCUS_OUTER
    @fallback = fallback
    freeze
  end

  def fallback?
    @fallback
  end

  def ratio_label
    "#{Kernel.format('%.2f', contrast_ratio)}:1"
  end

  def inline_style
    [
      "background-color: #{background}",
      "color: #{foreground}",
      "border-color: #{border_colour}",
      "--category-focus-inner: #{focus_inner}",
      "--category-focus-outer: #{focus_outer}"
    ].join("; ").concat(";")
  end

  def selected_style
    "#{inline_style} box-shadow: inset 0 0 0 2px #{foreground};"
  end

  def disabled_style
    "#{inline_style} border-style: dashed;"
  end

  def chart_payload
    { background:, foreground: }
  end

  alias chart_background background
  alias chart_foreground foreground
end
