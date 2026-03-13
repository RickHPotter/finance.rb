# frozen_string_literal: true

module Components
  class InstallmentsCountRangeFields < Base
    include TranslateHelper
    include CacheHelper

    attr_reader :form, :from_field, :to_field, :from_value, :to_value, :subject_label_key

    def initialize(form:, from_field:, to_field:, from_value:, to_value:, subject_label_key:) # rubocop:disable Metrics/ParameterLists
      @form = form
      @from_field = from_field
      @to_field = to_field
      @from_value = from_value
      @to_value = to_value
      @subject_label_key = subject_label_key
    end

    def view_template
      div class: "grid grid-cols-11 my-auto mb-1" do
        div class: "col-span-11 font-graduate flex gap-1 justify-center" do
          thin__label(form, :count)
          thin__label(form, subject_label_key)
        end

        div class: "col-span-5 my-auto" do
          TextFieldTag \
            from_field,
            type: :number,
            svg: :number,
            min: 1, max: 72,
            value: from_value
        end

        div(class: "m-auto") do
          cached_icon :exchange
        end

        div class: "col-span-5 my-auto" do
          TextFieldTag \
            to_field,
            type: :number,
            svg: :number,
            min: 1, max: 72,
            value: to_value
        end
      end
    end

    private

    def thin__label(form, field)
      span(class: "font-poetsen-one font-thin text-gray-500") { model_attribute(form.object, field).downcase }
    end
  end
end
