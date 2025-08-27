# frozen_string_literal: true

module Components
  class ColourPicker < Base
    def initialize(form:, field:, &)
      @form = form
      @field = field
      @value = form.object.send(field) || :white
      @colour = ::COLOURS.dig(@value, :hex) || @value
    end

    def view_template
      div class: "relative", data: { controller: "colour-picker" } do
        div class: "relative", data: { action: "click->colour-picker#toggle" } do
          raw @form.text_field(@field, type: :hidden, value: @colour, readonly: true, data: { colour_picker_target: "selectedValue" })

          div(class: "w-10 h-10 rounded-full border-1", style: "background-color: #{@colour}", data: { colour_picker_target: "indicator" })
        end

        div class: "hidden absolute z-50 w-72 mt-2 p-3 left-1/2 -translate-x-1/2 bg-white rounded-lg shadow-lg border border-zinc-300",
            data: { colour_picker_target: "optionContainer" } do
          div class: "grid grid-cols-8 gap-2 mb-3" do
            COLOURS.each_pair do |name, classes|
              button type: "button",
                     class: "w-7 h-7 rounded border shadow-sm hover:scale-110 transition",
                     style: "background-color: #{classes[:hex]}",
                     title: name,
                     data: {
                       action: "click->colour-picker#selectColour",
                       colour_picker_target: "option",
                       value: classes[:hex]
                     }
            end
          end

          div class: "flex items-center gap-2 p-1" do
            input type: "color",
                  value: @colour,
                  class: "size-10 rounded cursor-pointer",
                  data: { action: "input->colour-picker#pickCustom", colour_picker_target: "customInput" }

            input type: "text",
                  placeholder: "#aabbcc",
                  value: @colour,
                  class: "w-full uppercase text-black text-center text-ellipsis text-xl lg:text-2xl xl:text-3xl 2xl:text-4xl font-extrabold
                          border-0 focus:border-0 focus:ring-0 focus:outline-hidden sm:tracking-tight".squish,
                  data: { action: "input->colour-picker#hexChanged", colour_picker_target: "hexField" }
          end
        end
      end
    end
  end
end
