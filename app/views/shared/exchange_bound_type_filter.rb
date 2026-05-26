# frozen_string_literal: true

class Views::Shared::ExchangeBoundTypeFilter < Views::Base
  attr_reader :current_state, :input_name, :form_id

  def initialize(current_state:, input_name: "exchange_bound_type", form_id: nil)
    @current_state = current_state.presence || "all"
    @input_name = input_name.to_s
    @form_id = form_id
  end

  def view_template
    div(class: "mb-2 grid grid-cols-1 gap-y-2 w-full") do
      span(class: "font-poetsen-one font-thin text-xs text-gray-500") { I18n.t("filters.exchange_bound_type.label") }

      select(
        name: input_name,
        form: form_id,
        id: input_name,
        class: [
          "w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm font-semibold text-slate-700",
          "outline-none transition focus:border-blue-500 focus:ring-2 focus:ring-blue-200"
        ].join(" "),
        data: {
          controller: "request-submit",
          request_submit_form_id_value: form_id,
          action: "change->request-submit#submit"
        }
      ) do
        option(value: "all", selected: current_state == "all") { I18n.t("filters.exchange_bound_type.all") }
        option(value: "card_bound", selected: current_state == "card_bound") { I18n.t("filters.exchange_bound_type.card_bound") }
        option(value: "standalone", selected: current_state == "standalone") { I18n.t("filters.exchange_bound_type.standalone") }
      end
    end
  end
end
