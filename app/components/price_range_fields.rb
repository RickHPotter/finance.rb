# frozen_string_literal: true

module Components
  class PriceRangeFields < Base
    include TranslateHelper
    include CacheHelper

    attr_reader :form, :from_field, :to_field, :from_value, :to_value, :object, :subject_label_key

    def initialize(form:, object:, from_field:, to_field:, from_value:, to_value:, subject_label_key:) # rubocop:disable Metrics/ParameterLists
      @form = form
      @object = object
      @from_field = from_field
      @to_field = to_field
      @from_value = from_value
      @to_value = to_value
      @subject_label_key = subject_label_key
    end

    def view_template
      div class: "grid grid-cols-11 gap-y-1 my-auto mb-2" do
        div class: "col-span-11 font-graduate flex gap-1 justify-center" do
          thin__label(form, :price)
          thin__label(form, subject_label_key)
        end

        div class: "col-span-11 lg:col-span-5 my-auto" do
          price_field(from_field, from_value)
        end

        div(class: "hidden lg:flex m-auto") do
          cached_icon :exchange
        end

        div class: "col-span-11 lg:col-span-5 my-auto" do
          price_field(to_field, to_value)
        end
      end
    end

    private

    def price_field(field, value)
      sign = sign_for(value)
      target_class = price_target_class(field)

      div(class: "flex gap-1") do
        Button(
          size: :lg,
          class: "w-10 shrink-0 #{sign_bg_colour(sign)} border border-black lg:hidden",
          tabindex: -1,
          title: action_message(:toggle_sign),
          data: { action: "click->price-mask#toggleSign", target: ".#{target_class}" }
        ) { sign }

        div(class: "min-w-0 flex-1") do
          TextFieldTag \
            field,
            inputmode: :numeric,
            svg: :money,
            value:,
            class: "#{target_class} font-graduate",
            placeholder: model_attribute(object, field),
            data: {
              controller: "input-select",
              price_mask_target: :input,
              action: "click->input-select#select input->price-mask#applyMask",
              sign:
            }
        end
      end
    end

    def sign_for(value)
      value.to_i.negative? ? "-" : "+"
    end

    def sign_bg_colour(sign)
      sign == "-" ? "bg-red-300" : "bg-green-300"
    end

    def price_target_class(field)
      "price-range-#{field.to_s.tr('_', '-')}"
    end
  end
end
