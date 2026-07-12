# frozen_string_literal: true

module Views
  class Base < Components::Base
    include Phlex::Rails::Helpers::TurboFrameTag

    register_output_helper :combobox_tag

    def rails_view_context
      context[:rails_view_context]
    end

    def params
      rails_view_context.params
    end

    def request
      rails_view_context.request
    end

    def current_context
      return nil unless request&.env&.[]("warden").present?

      rails_view_context.current_context
    end

    def mobile?
      rails_view_context.instance_variable_get(:@mobile) || false
    end

    def render_scenario_badge
      return if current_context.blank? || current_context.main?

      badge_class = "mt-2 flex w-fit self-start items-start border-l-4 border-red-700 bg-rose-400/30 " \
                    "px-3 py-1 text-2xs font-semibold uppercase"

      div(class: badge_class) do
        plain(Context.model_name.human)
        plain(": ")
        plain(current_context.main? ? I18n.t("contexts.index.main_label") : current_context.name)
      end
    end

    def mobile_stat(label, value, full_width: false)
      div(class: "#{'col-span-2' if full_width} rounded-2xl border border-slate-200 bg-slate-50 px-3 py-2") do
        p(class: "text-2xs font-semibold uppercase tracking-[0.16em] text-slate-500") { label }
        p(class: "mt-1 text-sm font-bold text-slate-950") { value.to_s }
      end
    end

    def form_badge_class(mode)
      light_base = "inline-flex border-l-5 px-2 py-1 text-sm font-bold uppercase"
      dark_base = "dark:rounded-md dark:font-mono dark:font-semibold dark:tracking-wide"

      case mode
      when :new then "#{light_base} #{dark_base} border-purple-500 bg-purple-100 text-purple-900 dark:border-purple-500 dark:bg-slate-900 dark:text-purple-300"
      when :edit then "#{light_base} #{dark_base} border-sky-500 bg-sky-100 text-sky-900 dark:border-sky-500 dark:bg-slate-900 dark:text-sky-300"
      when :duplicate
        "#{light_base} #{dark_base} border-orange-500 bg-orange-100 text-orange-900 dark:border-orange-500 dark:bg-slate-900 dark:text-orange-300"
      end
    end

    def index_new_button_class
      "hidden md:flex items-center gap-2 rounded-md border border-purple-500 bg-purple-100 px-3 py-2 text-purple-900 shadow-sm transition-colors " \
        "hover:border-purple-400 hover:bg-purple-500 hover:text-white dark:border-purple-500 dark:bg-slate-900 dark:text-purple-300 " \
        "dark:hover:border-purple-400 dark:hover:bg-purple-500 dark:hover:text-white"
    end

    def form_action_mode(record)
      return :duplicate if record.respond_to?(:duplicate) && record.duplicate
      return :edit if record.respond_to?(:persisted?) && record.persisted?

      :new
    end

    def submit_button_class(mode)
      {
        new: "#{light_new_submit_button_class} #{dark_sky_submit_button_class}",
        edit: "#{light_edit_submit_button_class} #{dark_sky_submit_button_class}",
        duplicate: "#{light_duplicate_submit_button_class} #{dark_duplicate_submit_button_class}"
      }[mode]
    end

    def destroy_button_class
      "border-red-500 bg-red-100 text-red-900 hover:border-red-400 hover:bg-red-500 hover:text-white dark:border-red-700/60 " \
        "dark:bg-transparent dark:text-red-400 dark:hover:bg-red-900/30 dark:hover:text-red-400 dark:focus-visible:ring-2 " \
        "dark:focus-visible:ring-red-500/50"
    end

    def duplicate_button_class
      "min-w-64 border-orange-500 bg-orange-100 text-orange-900 hover:border-orange-400 hover:bg-orange-500 hover:text-white " \
        "dark:border-violet-700/60 dark:bg-transparent dark:text-violet-300 dark:hover:bg-violet-900/30 dark:hover:text-violet-300 " \
        "dark:focus-visible:ring-2 dark:focus-visible:ring-violet-500/60"
    end

    def secondary_submit_row_button_class(width_class = "w-64")
      "#{width_class} border-slate-400 bg-white text-slate-900 hover:border-slate-600 hover:bg-slate-100 " \
        "dark:border-slate-600 dark:bg-slate-900 dark:text-slate-200 dark:hover:bg-slate-800"
    end

    def light_new_submit_button_class
      "border-purple-900 bg-purple-500 text-white hover:border-purple-500 hover:bg-purple-100 hover:text-purple-900"
    end

    def light_edit_submit_button_class
      "border-sky-900 bg-sky-500 text-white hover:border-sky-500 hover:bg-sky-100 hover:text-sky-900"
    end

    def light_duplicate_submit_button_class
      "border-orange-800 bg-orange-500 text-white hover:border-orange-500 hover:bg-orange-100 hover:text-orange-900"
    end

    def dark_sky_submit_button_class
      "dark:border-sky-700/60 dark:bg-transparent dark:text-sky-300 dark:hover:bg-sky-900/30 dark:hover:text-sky-300 " \
        "dark:focus-visible:ring-2 dark:focus-visible:ring-sky-500/60"
    end

    def dark_duplicate_submit_button_class
      "dark:border-violet-700/60 dark:bg-transparent dark:text-violet-300 dark:hover:bg-violet-900/30 dark:hover:text-violet-300 " \
        "dark:focus-visible:ring-2 dark:focus-visible:ring-violet-500/60"
    end

    def modal_cancel_button_class
      "ml-2 rounded bg-gray-500 px-4 py-2 font-bold text-white hover:bg-gray-700 dark:border dark:border-slate-600 " \
        "dark:bg-slate-900 dark:text-slate-200 dark:hover:bg-slate-800"
    end

    def modal_confirm_button_class(color)
      color_class = {
        green: "bg-green-500 hover:bg-green-700 dark:border-green-500 dark:bg-green-700/80 dark:hover:bg-green-600",
        blue: "bg-blue-500 hover:bg-blue-700 dark:border-blue-500 dark:bg-blue-700/80 dark:hover:bg-blue-600",
        purple: "bg-purple-700 hover:bg-purple-800 dark:border-purple-500 dark:bg-purple-700/80 dark:hover:bg-purple-600"
      }.fetch(color)

      "#{color_class} rounded px-4 py-2 font-bold text-white dark:border"
    end

    def resource_index_shell_class
      "flex min-h-[calc(100svh-18rem)] flex-col rounded-lg bg-white p-4 shadow-md " \
        "dark:border dark:border-slate-800 dark:bg-slate-900 dark:text-slate-100 dark:shadow-none"
    end

    def resource_index_hero_class
      "mb-6 flex items-start justify-between border-b border-stone-200 pb-3 dark:border-slate-700"
    end

    def resource_index_title_class
      "text-sm font-semibold uppercase tracking-[0.2em] text-stone-700 dark:text-slate-300"
    end

    def resource_table_shell_class
      "overflow-hidden rounded-lg border border-slate-300 shadow-sm dark:border-slate-700 dark:bg-slate-950 dark:shadow-black/30"
    end

    def resource_empty_row_class
      "my-2 border-b border-slate-200 bg-white py-2 text-lg dark:border-slate-700 dark:bg-slate-950 dark:text-slate-100"
    end

    def resource_mobile_filter_shell_class
      "mb-6 grid grid-cols-1 gap-2 rounded-lg bg-slate-50 p-3 shadow-sm dark:border dark:border-slate-700 dark:bg-slate-900 dark:shadow-black/30"
    end

    def resource_mobile_filter_button_class
      "scale-105 dark:border-slate-700 dark:bg-slate-900 dark:text-slate-200 dark:hover:bg-slate-800"
    end

    def resource_mobile_filter_sheet_class
      "w-4/5 lg:w-1/2 dark:border-slate-700 dark:bg-slate-950 dark:text-slate-100"
    end

    def compact_crud_shell_class
      "m-1 min-h-[calc(100svh-16rem)] rounded-lg bg-white shadow-md shadow-red-50 " \
        "dark:border dark:border-slate-800 dark:bg-slate-900 dark:text-slate-100 dark:shadow-none"
    end

    def compact_crud_header_class
      "flex items-start justify-between border-b border-stone-200 px-4 py-3 dark:border-slate-700"
    end

    def compact_crud_title_class
      "text-sm font-semibold uppercase tracking-[0.2em] text-stone-700 dark:text-slate-300"
    end

    def compact_crud_panel_class
      "border-b border-stone-100 px-3 py-3 md:px-4 dark:border-slate-800"
    end
  end
end
