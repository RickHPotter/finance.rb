# frozen_string_literal: true

class Views::Shared::SortToolbar < Views::Base
  attr_reader :title, :options, :current_sort, :current_direction

  def initialize(title:, options:, current_sort:, current_direction:)
    @title = title
    @options = options
    @current_sort = current_sort
    @current_direction = current_direction
  end

  def view_template
    fieldset(class: container_class) do
      legend(class: "text-xs font-bold uppercase tracking-[0.20em] text-sky-900") { title }

      div(class: "grid gap-3 lg:grid-cols-[auto,1fr] lg:items-start") do
        div(class: "flex flex-wrap justify-center items-center gap-2") do
          options.each do |option|
            render_sort_button(**option)
          end
        end
      end
    end
  end

  private

  def render_sort_button(label:, field:, reset: false)
    button(
      type: "button",
      class: sort_button_class(field),
      title: label,
      data: {
        action: "click->datatable#submitSort",
        sort_field: field,
        sort_default_direction: "asc",
        sort_reset: reset.to_s
      },
      aria: { pressed: active_sort?(field).to_s }
    ) do
      span(class: "text-xs md:text-sm") { label }
      span(class: sort_badge_class(field)) { sort_badge_label(field) }
    end
  end

  def container_class
    "rounded-lg border border-sky-200 bg-sky-50 px-3 py-2 text-xs text-slate-700"
  end

  def sort_button_class(field)
    base = "inline-flex items-center gap-2 rounded-sm ring px-2 py-1 text-xs transition-colors"
    state =
      if active_sort?(field)
        "ring-blue-700 bg-blue-100 text-blue-900"
      else
        "ring-slate-400 bg-white text-slate-700 hover:ring-slate-600 hover:bg-slate-50"
      end

    "#{base} #{state}"
  end

  def sort_badge_class(field)
    base = "rounded px-1.5 py-0.5 text-[10px] font-bold tracking-wide"
    state = active_sort?(field) ? "bg-blue-700 text-white" : "bg-slate-200 text-slate-700"

    "#{base} #{state}"
  end

  def sort_badge_label(field)
    active_sort?(field) ? I18n.t("sorting.direction.#{current_direction}") : I18n.t("sorting.badge.idle")
  end

  def active_sort?(field)
    current_sort == field
  end
end
