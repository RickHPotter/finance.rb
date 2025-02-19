# frozen_string_literal: true

module Components
  class ColourPicker < Base
    def initialize(form:, field:, &)
      super
      @form = form
      @field = field
      @value = form.object.send(field) || :white
      @colour = ::COLOURS.dig(@value, :bg)
    end

    def view_template
      div(class: "relative", data: { controller: "colour-picker" }) do
        div(class: "relative", data: { action: "click->colour-picker#toggle" }) do
          raw @form.text_field(@field, type: :hidden, value: @value, readonly: true, data: { colour_picker_target: "selectedColour" })

          div(class: "w-6 h-6 rounded-full border-1 #{@colour}", data: { colour_picker_target: "colourIndicator" })
        end

        div(class: "hidden absolute z-50 w-32 mt-2 p-2 left-1/2 -translate-x-1/2 bg-white rounded-lg shadow-lg border border-zinc-300 grid grid-cols-4 gap-2",
            data: { colour_picker_target: "colourOptionContainer" }) do
          ::COLOURS.each_pair do |name, classes|
            button type: "button",
                   class: "w-6 h-6 rounded shadow-lg border hover:scale-125 transition-all ease-in-out duration-100 cursor-pointer
                          hover:border-black focus:outline-none #{classes[:bg]} #{classes[:text]} #{classes[:from]} #{classes[:via]} #{classes[:to]}",
                   title: name,
                   data: { action: "click->colour-picker#selectColour", colour_picker_target: "colourOption", name: name, bg: classes[:bg] }
          end
        end
      end
    end
  end
end
