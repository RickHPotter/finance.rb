# frozen_string_literal: true

class Views::CashTransactions::PaidStateFilter < Views::Base
  attr_reader :current_state

  def initialize(current_state:)
    @current_state = current_state
  end

  def view_template
    div(class: "mb-2 grid grid-cols-1 gap-y-2 w-full") do
      span(class: "font-poetsen-one font-thin text-xs text-gray-500") { I18n.t("filters.paid_state.label") }

      div(class: "grid grid-cols-3 gap-2") do
        render_option("all")
        render_option("paid")
        render_option("pending")
      end
    end
  end

  private

  def render_option(value)
    button(
      type: "button",
      class: option_class(value),
      title: I18n.t("filters.paid_state.#{value}"),
      data: {
        action: "click->reactive-form#applyPaidState",
        paid_state_value: value,
        paid_state_input_id: "cash_transactions_paid_state",
        paid_input_id: "cash_transactions_paid",
        pending_input_id: "cash_transactions_pending"
      },
      aria: { pressed: (current_state == value).to_s }
    ) { I18n.t("filters.paid_state.#{value}") }
  end

  def option_class(value)
    base = "inline-flex cursor-pointer items-center justify-center rounded-md border px-3 py-2 text-xs font-semibold uppercase tracking-[0.14em] transition"
    state =
      if current_state == value
        "border-blue-700 bg-blue-100 text-blue-900"
      else
        "border-slate-300 bg-white text-slate-600 hover:border-slate-500 hover:text-slate-900"
      end

    "#{base} #{state}"
  end
end
