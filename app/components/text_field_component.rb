# frozen_string_literal: true

# Component to render an input text field
class TextFieldComponent < ViewComponent::Base
  include ApplicationHelper
  include TranslateHelper
  attr_reader :options, :wrapper

  def initialize(form:, object:, field:, options: {}, wrapper: true)
    @object = object
    @field = field
    @options = default_options(options)
    @wrapper = wrapper
    super
  end

  def default_options(options)
    {
      id: options[:id] || "#{@object.model_name.singular}_#{@field}_select",
      label: options[:label] || attribute_model(@object, @field),
      type: options[:type] || 'text',
      step: options[:step] || '',
      data: data_attributes(options[:data])
    }
  end
end
