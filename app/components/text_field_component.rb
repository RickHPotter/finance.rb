# frozen_string_literal: true

# Component to render an input text field
class TextFieldComponent < CustomViewComponent
  include TranslateHelper
  attr_reader :label, :input

  def initialize(form:, object:, field:, options: {})
    @object = object
    @field = field
    @options = default_options(options)

    if form
      @label = form.label(@field, class: label_class)
      @input = form.text_field(@field, class: input_class, type: @options[:type], placeholder: ' ')
    else
      @label = content_tag(:label, @options[:label], class: label_class)
      @input = content_tag(:input, nil, class: input_class, type: @options[:type], placeholder: ' ')
    end
    super
  end

  def default_options(options)
    {
      colour: COLOURS[options[:colour].to_sym ||= 'indigo'],
      label: options[:label] || attribute_model(@object, @field),
      type: options[:type] || 'text'
    }
  end

  def input_class
    custom_input_class(colour: @options[:colour])
  end

  def label_class
    custom_label_class(colour: @options[:colour])
  end
end
