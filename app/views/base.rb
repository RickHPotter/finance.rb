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
      rails_view_context.current_context
    end

    def render_scenario_badge
      badge_class = "mt-2 inline-flex items-center border-l-4 border-red-700 bg-rose-400/30 " \
                    "px-3 py-1 text-[10px] font-semibold uppercase"

      div(class: badge_class) do
        plain(Context.model_name.human)
        plain(": ")
        plain(current_context.main? ? I18n.t("contexts.index.main_label") : current_context.name)
      end
    end
  end
end
