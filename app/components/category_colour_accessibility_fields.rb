# frozen_string_literal: true

module Components
  class CategoryColourAccessibilityFields < Base
    include TranslateHelper

    def initialize(form:, category:)
      @form = form
      @category = category
    end

    def view_template
      section(
        class: "mb-6 space-y-5 rounded-xl border border-slate-300 bg-slate-50 p-4 shadow-sm dark:border-slate-700 dark:bg-slate-900",
        aria_labelledby: "category_colour_accessibility_heading"
      ) do
        heading

        div(class: "grid gap-5 lg:grid-cols-2") do
          colour_picker_field(:colour, :background, "backgroundInput")
          text_colour_controls
        end

        contrast_status
        preview_canvases
        interaction_previews
      end
    end

    private

    attr_reader :form, :category

    def heading
      div do
        h2(id: "category_colour_accessibility_heading", class: "text-sm font-bold uppercase tracking-[0.16em] text-slate-800 dark:text-slate-100") do
          colour_translation(:heading)
        end
        p(class: "mt-1 text-sm text-slate-600 dark:text-slate-300") { colour_translation(:description) }
      end
    end

    def colour_picker_field(field, translation_key, target, value: nil)
      div(class: "flex items-center gap-4 rounded-lg border border-slate-200 bg-white p-3 dark:border-slate-700 dark:bg-slate-950") do
        ColourPicker(
          form:,
          field:,
          value:,
          label: colour_translation(translation_key),
          input_data: { category_colour_preview_target: target }
        )

        div do
          p(class: "text-sm font-semibold text-slate-900 dark:text-slate-100") { colour_translation(translation_key) }
          p(class: "text-xs text-slate-500 dark:text-slate-400") { colour_translation(:"#{translation_key}_hint") }
        end
      end
    end

    def text_colour_controls
      div(class: "space-y-3") do
        text_colour_mode_fields

        div(
          class: ("hidden" if category.text_colour_automatic?).to_s,
          aria_hidden: category.text_colour_automatic?.to_s,
          data: { category_colour_preview_target: "manualFields" }
        ) do
          colour_picker_field(
            :text_colour,
            :manual_foreground,
            "foregroundInput",
            value: category.text_colour.presence || category.resolved_text_colour || "#000000"
          )
        end
      end
    end

    def text_colour_mode_fields
      fieldset(class: "rounded-lg border border-slate-200 bg-white p-3 dark:border-slate-700 dark:bg-slate-950") do
        legend(class: "px-1 text-sm font-semibold text-slate-900 dark:text-slate-100") { model_attribute(category, :text_colour_mode) }

        div(class: "mt-2 grid grid-cols-2 gap-2") do
          %w[automatic manual].each { |mode| text_colour_mode_field(mode) }
        end
      end
    end

    def text_colour_mode_field(mode)
      id = "category_text_colour_mode_#{mode}"

      label(
        for: id,
        class: "flex cursor-pointer items-start gap-2 rounded-md border border-slate-300 p-2 text-sm text-slate-800 " \
               "has-checked:border-sky-600 has-checked:bg-sky-50 dark:border-slate-700 dark:text-slate-100 dark:has-checked:bg-slate-800"
      ) do
        raw form.radio_button(
          :text_colour_mode,
          mode,
          id:,
          data: {
            category_colour_preview_target: "modeInput",
            action: "change->category-colour-preview#modeChanged"
          }
        )

        span do
          strong(class: "block") { colour_translation(mode.to_sym) }
          small(class: "block text-xs text-slate-500 dark:text-slate-400") { colour_translation(:"#{mode}_hint") }
        end
      end
    end

    def contrast_status
      div(
        class: "grid gap-2 rounded-lg border border-slate-300 bg-white p-3 text-sm sm:grid-cols-[auto_1fr] dark:border-slate-700 dark:bg-slate-950",
        role: "status",
        aria_live: "polite"
      ) do
        strong(class: "text-slate-900 dark:text-slate-100") do
          plain "#{colour_translation(:contrast)} "
          span(data: { category_colour_preview_target: "ratio" }) { initial_ratio_label }
        end

        div do
          span(
            class: "font-semibold text-slate-700 dark:text-slate-200",
            data: { category_colour_preview_target: "status", state: initial_contrast_state }
          ) { initial_contrast_label }
          p(class: "text-xs text-slate-500 dark:text-slate-400", data: { category_colour_preview_target: "suggestion" }) { "" }
        end
      end
    end

    def preview_canvases
      div(class: "grid gap-3 sm:grid-cols-2") do
        preview_canvas(:light_preview, "bg-white text-slate-900")
        preview_canvas(:dark_preview, "bg-slate-950 text-slate-100")
      end
    end

    def preview_canvas(label_key, classes)
      div(class: "rounded-lg border border-slate-400 p-4 #{classes}") do
        p(class: "mb-3 text-xs font-bold uppercase tracking-[0.14em]") { colour_translation(label_key) }
        CategoryBadge(category:, label: preview_label, data: preview_data("normal"))
      end
    end

    def interaction_previews
      div(class: "rounded-lg border border-slate-300 bg-white p-3 dark:border-slate-700 dark:bg-slate-950") do
        p(class: "mb-3 text-xs font-bold uppercase tracking-[0.14em] text-slate-700 dark:text-slate-200") { colour_translation(:states) }

        div(class: "flex flex-wrap gap-4") do
          %i[normal hover focus selected disabled].each { |state| interaction_preview(state) }
        end
      end
    end

    def interaction_preview(state)
      div(class: "space-y-1 text-center") do
        small(class: "block text-xs text-slate-500 dark:text-slate-400") { colour_translation(state) }
        CategoryBadge(
          category:,
          label: preview_label,
          selected: state == :selected,
          disabled: state == :disabled,
          data: preview_data(state)
        )
      end
    end

    def preview_data(state)
      { category_colour_preview_target: "preview", preview_state: state }
    end

    def preview_label
      category.name.to_s.presence || colour_translation(:fallback_label)
    end

    def initial_assessment
      @initial_assessment ||= begin
        contrast = CategoryColours::Contrast.new(category.colour)
        category.text_colour_manual? ? contrast.assess(category.text_colour) : contrast.automatic_assessment
      rescue CategoryColours::Contrast::InvalidColour
        nil
      end
    end

    def initial_ratio_label
      initial_assessment&.ratio_label || "—"
    end

    def initial_contrast_state
      return "invalid" if initial_assessment.nil?

      initial_assessment.passing? ? "passing" : "failing"
    end

    def initial_contrast_label
      colour_translation(initial_contrast_state.to_sym)
    end

    def colour_translation(key)
      I18n.t("categories.colour_accessibility.#{key}")
    end
  end
end
