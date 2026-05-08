# frozen_string_literal: true

module RubyUI
  class TimePicker < Base
    def initialize(input_id:, value: nil, autofocus: false, **attrs)
      @input_id = input_id
      @value = value.presence || "00:00"
      @autofocus = autofocus
      super(**attrs)
    end

    def view_template
      div(**attrs) do
        time_column(label: "HH", target: "hour", decrement: "decrementHour", increment: "incrementHour", autofocus: @autofocus)
        time_column(label: "MM", target: "minute", decrement: "decrementMinute", increment: "incrementMinute")
      end
    end

    private

    def time_column(label:, target:, decrement:, increment:, autofocus: false)
      div(class: "grid min-w-0 flex-1 grid-rows-[auto_minmax(0,1fr)_auto] gap-1") do
        button(type: :button, class: button_class, data: { action: "ruby-ui--time-picker##{decrement}" }) { "-" }
        div(class: "flex min-w-0 flex-col items-center justify-center rounded-md border border-slate-200 bg-slate-50 px-1 py-1") do
          span(class: "text-2xs font-black uppercase tracking-[0.18em] text-slate-400") { label }
          input(
            type: "text",
            inputmode: "numeric",
            pattern: "[0-9]*",
            maxlength: 2,
            autofocus:,
            class: "h-8 w-full rounded-sm border-0 bg-transparent p-0 text-center font-graduate text-xl font-black text-slate-950 " \
                   "outline-hidden focus:bg-white focus:ring-1 focus:ring-slate-300",
            data: {
              controller: ("autofocus" if autofocus),
              autofocus_select_value: autofocus,
              ruby_ui__time_picker_target: target,
              action: "click->ruby-ui--time-picker#selectInput focus->ruby-ui--time-picker#selectInput input->ruby-ui--time-picker#editTime " \
                      "blur->ruby-ui--time-picker#commitEdit keydown->ruby-ui--time-picker#handleKeydown"
            }.compact
          )
        end
        button(type: :button, class: button_class, data: { action: "ruby-ui--time-picker##{increment}" }) { "+" }
      end
    end

    def button_class
      "inline-flex h-7 items-center justify-center rounded-md border border-slate-300 bg-white text-base font-black text-slate-700 " \
        "shadow-sm transition hover:bg-slate-100"
    end

    def default_attrs
      {
        class: "flex h-full w-full flex-col gap-1 rounded-md border border-slate-200 bg-white p-2 shadow-sm",
        data: {
          controller: "ruby-ui--time-picker",
          ruby_ui__time_picker_input_id_value: @input_id,
          ruby_ui__time_picker_time_value: @value
        }
      }
    end
  end
end
