# frozen_string_literal: true

module Components
  class CategoryBadge < Base
    VARIANTS = %i[badge swatch].freeze

    attr_reader :category, :compound, :count, :href, :label, :presentation, :variant

    def initialize(category:, href: nil, label: nil, variant: :badge, compound: true, selected: false, disabled: false, count: nil, **attrs)
      raise ArgumentError, "invalid category badge variant" unless variant.in?(VARIANTS)

      @category = category
      @href = href
      @label = label.presence || category.name
      @variant = variant
      @compound = compound
      @selected = selected
      @disabled = disabled
      @count = count == false ? nil : (count || default_count)
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
        contrast_ratio: presentation.ratio_label,
        selected: selected?.to_s
      )
      attrs[:aria] = (attrs[:aria] || {}).merge(label: accessible_label, disabled: disabled?.to_s)
      attrs[:aria][:current] = "true" if selected? && href.present?
    end

    def default_count
      return category.subcategories.size if category.respond_to?(:parent?) && category.parent?

      nil
    rescue StandardError
      nil
    end

    def count_bubble?
      variant == :badge && @count.present? && @count.positive?
    end

    def subcategory?
      compound && variant == :badge && category.respond_to?(:parent_category) && category.parent_category.present?
    end

    def state_style
      return presentation.disabled_style if disabled?
      return presentation.selected_style if selected?

      presentation.inline_style
    end

    def accessible_label
      base =
        if category.respond_to?(:parent_category) && category.parent_category.present?
          "#{category.parent_category.name} → #{label}"
        else
          label
        end

      return "#{base} (#{@count})" if count_bubble?

      base
    end

    def badge_content
      if variant == :swatch
        span(class: "sr-only") { accessible_label }
      elsif subcategory?
        span(class: "font-semibold opacity-75") { category.parent_category.name }
        span(class: "opacity-75 mx-1 font-medium") { "→" }
        span(class: "font-bold", data: { category_child_badge: "true" }) { label }
        render_count_bubble if count_bubble?
      else
        plain label
        render_count_bubble if count_bubble?
      end
    end

    def render_count_bubble
      span(
        class: "ml-1.5 inline-flex items-center justify-center rounded-full bg-current/15 px-1.5 py-0.5 text-[10px] font-bold leading-none",
        title: "#{@count} #{I18n.t('categories.subcategories_label')}",
        data: { category_subcategories_count: "true" }
      ) { @count.to_s }
    end

    def selected?
      @selected
    end

    def disabled?
      @disabled
    end
  end
end
