# frozen_string_literal: true

module Components
  class ColourPicker < Base
    def initialize(form:, field:, value: nil, label: nil, input_data: {})
      @form = form
      @field = field
      @raw_value = (value || form.object.public_send(field)).to_s
      @colour = normalized_colour(@raw_value) || "#000000"
      @label = label || field.to_s.humanize
      @input_data = input_data
      @picker_id = "#{form.object_name}_#{field}_picker"
    end

    def view_template
      div class: "relative", data: { controller: "colour-picker", colour_picker_field_value: @field } do
        raw @form.hidden_field(
          @field,
          value: @raw_value.presence || @colour,
          data: { colour_picker_target: "selectedValue" }.merge(@input_data)
        )

        button(
          type: :button,
          class: "inline-flex size-12 items-center justify-center rounded-full border border-slate-400 bg-white shadow-sm " \
                 "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-sky-500 focus-visible:ring-offset-2",
          aria_label: @label,
          aria_expanded: "false",
          aria_controls: @picker_id,
          data: { action: "click->colour-picker#toggle", colour_picker_target: "trigger" }
        ) do
          span(
            class: "size-9 rounded-full border border-slate-300",
            style: "background-color: #{@colour}",
            data: { colour_picker_target: "indicator", valid: normalized_colour(@raw_value).present? }
          )
        end

        div id: @picker_id,
            class: "hidden absolute z-50 w-72 mt-2 p-3 left-1/2 -translate-x-1/2 bg-white rounded-lg shadow-lg border border-zinc-300",
            data: { colour_picker_target: "optionContainer" } do
          div class: "grid grid-cols-8 gap-2 mb-3" do
            COLOURS.each_pair do |name, classes|
              button type: "button",
                     class: "w-7 h-7 rounded border shadow-sm hover:scale-110 transition",
                     style: "background-color: #{classes[:hex]}",
                     title: name,
                     aria_label: name.to_s.humanize,
                     aria_pressed: "false",
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
                  aria_label: @label,
                  data: { action: "input->colour-picker#pickCustom", colour_picker_target: "customInput" }

            input type: "text",
                  placeholder: "#aabbcc",
                  value: @raw_value.presence || @colour,
                  class: "w-full uppercase text-black text-center text-ellipsis text-xl lg:text-2xl xl:text-3xl 2xl:text-4xl font-extrabold
                          border-0 focus:border-0 focus:ring-0 focus:outline-hidden sm:tracking-tight".squish,
                  aria_label: @label,
                  autocomplete: "off",
                  spellcheck: "false",
                  data: { action: "input->colour-picker#hexChanged", colour_picker_target: "hexField" }
          end
        end
      end
    end

    private

    def normalized_colour(value)
      CategoryColours::Contrast.normalize(value)
    rescue CategoryColours::Contrast::InvalidColour
      nil
    end
  end
end
