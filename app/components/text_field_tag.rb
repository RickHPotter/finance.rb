# frozen_string_literal: true

module Components
  class TextFieldTag < Base
    include Phlex::Rails::Helpers::TextFieldTag
    include Phlex::Rails::Helpers::SelectTag

    include ComponentsHelper
    include CacheHelper
    include TranslateHelper

    attr_reader :field, :items, :options

    TAGS = %i[multiple selected].freeze

    def initialize(field, items = nil, **options)
      @items = items
      @field = field
      @options = default_options(options)
    end

    def view_template
      div(class: "relative w-full") do
        div(class: "absolute inset-y-0 start-0 flex items-center ps-3.5 pointer-events-none z-1") do
          cached_icon options[:svg] if options[:svg]
        end

        value = options.delete(:value)

        if options[:type] == :select && items.present?
          select_tag field, items, options
        elsif options[:type] == :textarea
          text_area_tag field, value, options
        else
          text_field_tag field, value, options
        end
      end
    end

    def default_options(options)
      options[:class] = [ input_class, options[:class] ].compact.join(" ")

      {
        id: field,
        label: field,
        autocomplete: field
      }.merge(options)
    end
  end
end
