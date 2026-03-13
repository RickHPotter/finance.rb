# frozen_string_literal: true

module Components
  class PriceRangeFields < Base
    include TranslateHelper
    include CacheHelper

    attr_reader :form, :from_field, :to_field, :from_value, :to_value, :object, :subject_label_key

    def initialize(form:, object:, from_field:, to_field:, from_value:, to_value:, subject_label_key:)
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
          TextFieldTag \
            from_field,
            svg: :money,
            value: from_value,
            placeholder: model_attribute(object, from_field),
            onclick: "this.select();",
            data: { price_mask_target: :input, action: "input->price-mask#applyMask" }
        end

        div(class: "hidden lg:flex m-auto") do
          cached_icon :exchange
        end

        div class: "col-span-11 lg:col-span-5 my-auto" do
          TextFieldTag \
            to_field,
            svg: :money,
            value: to_value,
            placeholder: model_attribute(object, to_field),
            onclick: "this.select();",
            data: { price_mask_target: :input, action: "input->price-mask#applyMask" }
        end
      end
    end

    private

    def thin__label(form, field)
      span(class: "font-poetsen-one font-thin text-gray-500") { model_attribute(form.object, field).downcase }
    end
  end
end
