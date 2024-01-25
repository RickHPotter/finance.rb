# frozen_string_literal: true

# Component to render an input text field
class TextFieldComponent < ViewComponent::Base
  # @includes .................................................................
  include ComponentsHelper
  include TranslateHelper

  # @security (i.e. attr_accessible) ..........................................
  attr_reader :form, :object, :field, :options, :wrapper

  # @public_instance_methods ..................................................
  # Initialises a Component of Type TextField
  #
  # @param form [ActionView::Helpers::FormBuilder] The form builder object.
  # @param object [Object] The model object associated with the form.
  # @param field [Symbol] The attribute name for the text field.
  # @param options [Hash] Additional options for customizing the text field.
  #
  # @option options [String] :id The HTML ID attribute for the text field.
  # @option options [String] :label The label for the text field.
  # @option options [String] :type The input type (default is 'text').
  # @option options [String] :step The step attribute for number inputs.
  # @option options [Boolean] :autofocus Whether the text field should be autofocused (default is false).
  # @option options [String] :autocomplete The autocomplete attribute for the text field (default is the field name).
  # @option options [Hash] :data Additional data attributes for the text field.
  # @param wrapper [Boolean] Whether to include the wrapper for the text field (default is true).
  #
  # @return [TextFieldComponent] A new instance of TextFieldComponent.
  #
  def initialize(form:, object:, field:, options: {}, wrapper: true)
    @form = form
    @object = object
    @field = field
    @options = default_options(options)
    @wrapper = wrapper
    super
  end

  # Sets default options for the text field.
  #
  # @param options [Hash] Additional options for customizing the text field.
  #
  # @return [Hash] Merged options with default values.
  #
  def default_options(options)
    {
      id: options[:id] || "#{@object.model_name.singular}_#{@field}",
      label: options[:label] || attribute_model(@object, @field),
      type: options[:type] || 'text',
      step: options[:step] || '',
      autofocus: options[:autofocus] || false,
      autocomplete: options[:autocomplete] || @field,
      data: { form_validate_target: 'field' }.merge(options[:data] || {})
    }
  end
end
