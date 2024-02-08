# frozen_string_literal: true

# Component to render an input text field
class TextFieldComponent < ViewComponent::Base
  # @includes .................................................................
  include ComponentsHelper
  include TranslateHelper

  # @security (i.e. attr_accessible) ..........................................
  attr_reader :form, :object, :field, :items, :options, :wrapper

  # @public_instance_methods ..................................................
  # Initialises a Component of Type TextField
  #
  # @param form [ActionView::Helpers::FormBuilder] The form builder object.
  # @param field [Symbol] The attribute name for the text field.
  # @param items [Array] Array of Item Structs.
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
  def initialize(form:, field:, items: nil, options: {}, wrapper: true)
    @form = form
    @object = form.object || form.options[:parent_builder].object
    @items = items
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
    options[:data] = { form_validate_target: "field" }.merge(options[:data] || {})

    {
      id: "#{@object.model_name.singular}_#{@field}",
      label: attribute_model(@object, @field),
      autocomplete: @field,
      class: input_class
    }.merge(options)
  end
end
