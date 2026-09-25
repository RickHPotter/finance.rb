# frozen_string_literal: true

module Components
  class CategoryBadge < Base
    VARIANTS = %i[badge swatch].freeze

    attr_reader :category, :compound, :href, :label, :presentation, :variant

    def initialize(category:, href: nil, label: nil, variant: :badge, compound: true, selected: false, disabled: false, **attrs)
      raise ArgumentError, "invalid category badge variant" unless variant.in?(VARIANTS)

      @category = category
      @href = href
      @label = label.presence || category.name
      @variant = variant
      @compound = compound
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
        style: state_style
      }
    end

    def badge_classes
      classes = [
        "inline-flex items-center justify-center border font-semibold no-underline transition-shadow hover:shadow-md",
        "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--category-focus-inner)] " \
        "focus-visible:ring-offset-2 focus-visible:ring-offset-[var(--category-focus-outer)]"
      ]
      classes << if variant == :swatch
                   "size-5 rounded-full p-0"
                 elsif subcategory?
                   "rounded-md pl-2 pr-1 py-0.5 text-xs gap-1.5"
                 else
                   "rounded-md px-2 py-1 text-sm"
                 end
      classes << "ring-2 ring-[var(--category-focus-inner)] ring-offset-1 ring-offset-[var(--category-focus-outer)]" if selected?
      classes << "cursor-not-allowed border-dashed" if disabled?
      classes.join(" ")
    end

    def apply_accessible_attributes!
      attrs[:style] = state_style
      attrs[:data] = (attrs[:data] || {}).merge(
        category_colour: "true",
        category_id: category.id,
        contrast_ratio: active_presentation.ratio_label,
        selected: selected?.to_s
      )
      attrs[:aria] = (attrs[:aria] || {}).merge(label: accessible_label, disabled: disabled?.to_s)
      attrs[:aria][:current] = "true" if selected? && href.present?
    end

    def subcategory?
      compound && variant == :badge && category.respond_to?(:parent_category) && category.parent_category.present?
    end

    def parent_presentation
      @parent_presentation ||= CategoryColours::Presentation.for(category.parent_category)
    end

    def active_presentation
      subcategory? ? parent_presentation : presentation
    end

    def state_style
      return active_presentation.disabled_style if disabled?
      return active_presentation.selected_style if selected?

      active_presentation.inline_style
    end

    def child_state_style
      return presentation.disabled_style if disabled?
      return presentation.selected_style if selected?

      presentation.inline_style
    end

    def accessible_label
      if category.respond_to?(:parent_category) && category.parent_category.present?
        "#{category.parent_category.name} - #{label}"
      else
        label
      end
    end

    def badge_content
      if variant == :swatch
        span(class: "sr-only") { accessible_label }
      elsif subcategory?
        span(class: "font-bold tracking-tight text-xs mr-0.5") { category.parent_category.name }
        span(
          class: "inline-flex items-center rounded px-1.5 py-0.5 text-xs font-semibold border shadow-xs",
          style: child_state_style,
          data: { category_child_badge: "true" }
        ) { label }
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
