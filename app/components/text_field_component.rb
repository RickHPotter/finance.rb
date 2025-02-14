# frozen_string_literal: true

# Component to render an input text field
module Components
  class TextFieldComponent < ViewComponent::Base
    # @includes .................................................................
    include ComponentsHelper
    include TranslateHelper

    # @security (i.e. attr_accessible) ..........................................
    attr_reader :form, :object, :field, :items, :options, :wrapper

    # @public_instance_methods ..................................................

    # Initialises a TextField Component.
    #
    # @param form [ActionView::Helpers::FormBuilder] The form builder object.
    # @param field [Symbol] The attribute name for the text field.
    # @param items [Array] Array of Item Structs.
    # @param options [Hash] Additional options for customizing the text field.
    # @param wrapper [Boolean] Whether to include the wrapper for the text field (default is true).
    #
    # @option options [String] :id The HTML ID attribute for the text field.
    # @option options [String] :label The label for the text field.
    # @option options [String] :type The input type (default is 'text').
    # @option options [String] :step The step attribute for number inputs.
    # @option options [Boolean] :autofocus Whether the text field should be autofocused (default is false).
    # @option options [String] :autocomplete The autocomplete attribute for the text field (default is the field name).
    # @option options [Hash] :data Additional data attributes for the text field.
    # @option options [String] :svg The name of the SVG partial to use for the text field.
    #
    # @return [TextFieldComponent] A new instance of TextFieldComponent.
    #
    def initialize(form, field, items = nil, **options)
      @form = form
      @object = form.object || form.options[:parent_builder].object
      @items = items
      @field = field
      @wrapper = options.delete(:wrapper) || true
      @options = default_options(options)
      super
    end

    # Sets default `options` for the text field.
    #
    # @param options [Hash] Additional options for customizing the text field.
    #
    # @return [Hash] Merged options with default values.
    #
    def default_options(options)
      options[:data] = { form_validate_target: "field" }.merge(options[:data] || {})
      options[:class] = [ input_class, options[:class] ].compact.join(" ")

      {
        id: "#{@object.model_name.singular}_#{@field}",
        label: attribute_model(@object, @field),
        autocomplete: @field
      }.merge(options)
    end
  end
end
