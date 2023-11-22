# frozen_string_literal: true

# Component to render an input text field
class TextFieldComponent < ViewComponent::Base
  # includes ..................................................................
  include ComponentsHelper
  include TranslateHelper

  # security (i.e. attr_accessible) ...........................................
  attr_reader :form, :object, :field, :options, :wrapper

  # public instance methods ...................................................
  def initialize(form:, object:, field:, options: {}, wrapper: true)
    @form = form
    @object = object
    @field = field
    @options = default_options(options)
    @wrapper = wrapper
    super
  end

  # private instance methods ..................................................
  private

  def default_options(options)
    {
      id: options[:id] || "#{@object.model_name.singular}_#{@field}",
      label: options[:label] || attribute_model(@object, @field),
      type: options[:type] || 'text',
      step: options[:step] || '',
      autofocus: options[:autofocus] || false,
      autocomplete: options[:autocomplete] || @field,
      data: data_attributes(options[:data])
    }
  end
end
