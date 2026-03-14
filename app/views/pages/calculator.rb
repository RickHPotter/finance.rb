# frozen_string_literal: true

class Views::Pages::Calculator < Views::Base
  include TranslateHelper
  include ComponentsHelper
  include CacheHelper

  def view_template
    Sheet do
      SheetTrigger(class: "flex justify-center items-center fixed bottom-0 right-0 hidden sm:block rounded-full shadow-lg z-50") do
        Button(type: :button, icon: true, class: "m-4 bg-orange-600 text-black") do
          cached_icon(:calculator)
        end
      end

      SheetContent(
        side: :middle,
        no_blur: true,
        class: "rounded-2xl m-1 text-black select-none",
        data: { controller: :drag }
      ) do
        div(class: "flex justify-start items-center bg-white") do
          div(data: { drag_target: :handle }) do
            div(class: "pointer-events-none") do
              cached_icon(:expand)
            end
          end
        end

        SheetMiddle do
          calculator
        end
      end
    end
  end

  def calculator
    div(class: "flex h-full bg-gray-900 text-black rounded-lg shadow-lg font-lekton", data_controller: "calculator") do
      div(class: "flex-1 p-6") do
        div(class: "flex justify-between items-center mb-4") do
          h2(class: "text-2xl font-bold text-white") { I18n.t("calculator.title") }
        end

        input(
          type: "text",
          class: "w-full border-0 rounded-md p-4 text-right text-white mb-4 text-4xl font-mono bg-gray-800",
          data_calculator_target: "display",
          data_action: "keydown.enter->calculator#calculate input->calculator#sanitizeInput"
        )

        div(class: "grid grid-cols-4 gap-3") do
          %w[7 8 9 / 4 5 6 * 1 2 3 - 0 . = +].each do |val|
            button(
              tabindex: -1,
              class: button_class(val),
              data: { action: button_action(val), value: val }
            ) { val }
          end

          button(tabindex: -1, class: button_class("C", "bg-red-500 hover:bg-red-600"), data_action: "click->calculator#clear") { "C" }
          button(tabindex: -1, class: button_class("DEL", "bg-yellow-500 hover:bg-yellow-600 col-span-3"), data_action: "click->calculator#delete") { "DEL" }
        end
      end

      div(class: "w-72 bg-gray-800 p-6 overflow-y-auto rounded-r-lg border-l border-gray-700") do
        h3(class: "text-lg font-semibold text-gray-300 mb-4") { I18n.t("calculator.history") }
        ul(
          class: "text-base text-gray-400 space-y-2 overflow-y-auto h-96",
          data_calculator_target: "history"
        )
      end
    end
  end

  private

  def button_class(value, extra_classes = "bg-gray-700 hover:bg-gray-600")
    base_classes = "rounded-lg p-4 text-xl font-semibold border-0 text-white transition-all duration-150 ease-in-out"
    operator_classes = "bg-orange-500 hover:bg-orange-600"
    equals_classes = "bg-blue-500 hover:bg-blue-600"

    case value
    when "/", "*", "-", "+"
      "#{base_classes} #{operator_classes}"
    when "="
      "#{base_classes} #{equals_classes}"
    else
      "#{base_classes} #{extra_classes}"
    end
  end

  def button_action(value)
    value == "=" ? "click->calculator#calculate" : "click->calculator#append"
  end
end
