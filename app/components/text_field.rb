# frozen_string_literal: true

module Components
  class TextField < Base
    include ComponentsHelper
    include CacheHelper
    include TranslateHelper

    attr_reader :form, :object, :field, :items, :options, :wrapper

    def initialize(form, field, items = nil, **options)
      @form = form
      @object = form.object || form.options[:parent_builder]&.object
      @items = items
      @field = field
      @wrapper = options.delete(:wrapper) || true
      @options = default_options(options)
    end

    def view_template
      div(class: "relative w-full") do
        div(class: "absolute inset-y-0 start-0 flex items-center ps-3.5 pointer-events-none z-1") do
          cached_icon options[:svg] if options[:svg]
        end

        if options[:type] == :select && items.present?
          form.select field, items, {}, options
        elsif options[:type] == :textarea
          form.text_area field, options
        else
          form.text_field field, options
        end
      end
    end

    def default_options(options)
      options[:data] = { form_validate_target: "field" }.merge(options[:data] || {})
      options[:class] = [ input_class, options[:class] ].compact.join(" ")

      {
        id: "#{@object.model_name.singular}_#{@field}",
        label: model_attribute(@object, @field),
        autocomplete: @field
      }.merge(options)
    end
  end
end
