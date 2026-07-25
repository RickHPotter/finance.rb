# frozen_string_literal: true

module Components
  class CategoryBadge < Base
    VARIANTS = %i[badge swatch].freeze

    attr_reader :category, :href, :label, :presentation, :variant

    def initialize(category:, href: nil, label: nil, variant: :badge, selected: false, disabled: false, **attrs) # rubocop:disable Metrics/ParameterLists
      raise ArgumentError, "invalid category badge variant" unless variant.in?(VARIANTS)

      @category = category
      @href = href
      @label = label.presence || category.name
      @variant = variant
      @selected = selected
      @disabled = disabled
      @presentation = CategoryColours::Presentation.for(category)

      attrs.delete(:style)
      super(**attrs)
      apply_accessible_attributes!
    end

    def view_template
      if href.present? && !disabled?
        a(href:, **attrs) { badge_content }
      else
        span(**attrs) { badge_content }
      end
    end

    private

    def default_attrs
      {
        class: badge_classes,
        style: presentation.inline_style
      }
    end

    def badge_classes
      classes = [
        "inline-flex items-center justify-center border font-semibold no-underline transition-shadow hover:shadow-md",
        "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--category-focus-inner)] " \
        "focus-visible:ring-offset-2 focus-visible:ring-offset-[var(--category-focus-outer)]"
      ]
      classes << (variant == :swatch ? "size-5 rounded-full p-0" : "rounded-md px-2 py-1 text-sm")
      classes << "ring-2 ring-[var(--category-focus-inner)] ring-offset-1 ring-offset-[var(--category-focus-outer)]" if selected?
      classes << "cursor-not-allowed border-dashed" if disabled?
      classes.join(" ")
    end

    def apply_accessible_attributes!
      attrs[:style] = state_style
      attrs[:data] = (attrs[:data] || {}).merge(
        category_colour: "true",
        category_id: category.id,
        contrast_ratio: presentation.ratio_label,
        selected: selected?.to_s
      )
      attrs[:aria] = (attrs[:aria] || {}).merge(label:, disabled: disabled?.to_s)
      attrs[:aria][:current] = "true" if selected? && href.present?
    end

    def state_style
      return presentation.disabled_style if disabled?
      return presentation.selected_style if selected?

      presentation.inline_style
    end

    def badge_content
      if variant == :swatch
        span(class: "sr-only") { label }
      else
        plain label
      end
    end

    def selected?
      @selected
    end

    def disabled?
      @disabled
    end
  end
end
