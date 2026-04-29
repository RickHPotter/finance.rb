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
      base = "inline-flex border-l-5 px-2 py-1 text-sm font-bold uppercase"

      case mode
      when :new then "#{base} border-purple-500 bg-purple-100 text-purple-900"
      when :edit then "#{base} border-sky-500 bg-sky-100 text-sky-900"
      when :duplicate then "#{base} border-orange-500 bg-orange-100 text-orange-900"
      end
    end

    def index_new_button_class
      "hidden md:flex items-center gap-2 rounded-md border border-purple-500 bg-purple-100 px-3 py-2 text-purple-900 shadow-sm transition-colors " \
        "hover:border-purple-400 hover:bg-purple-500 hover:text-white"
    end

    def form_action_mode(record)
      return :duplicate if record.respond_to?(:duplicate) && record.duplicate
      return :edit if record.respond_to?(:persisted?) && record.persisted?

      :new
    end

    def submit_button_class(mode)
      {
        new: "border-purple-900 bg-purple-500 text-white hover:border-purple-500 hover:bg-purple-100 hover:text-purple-900",
        edit: "border-sky-900 bg-sky-500 text-white hover:border-sky-500 hover:bg-sky-100 hover:text-sky-900",
        duplicate: "border-orange-800 bg-orange-500 text-white hover:border-orange-500 hover:bg-orange-100 hover:text-orange-900"
      }[mode]
    end

    def destroy_button_class
      "border-red-500 bg-red-100 text-red-900 hover:border-red-400 hover:bg-red-500 hover:text-white"
    end

    def duplicate_button_class
      "min-w-64 border-orange-500 bg-orange-100 text-orange-900 hover:border-orange-400 hover:bg-orange-500 hover:text-white"
    end
  end
end
