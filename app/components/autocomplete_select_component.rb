# frozen_string_literal: true

# Component to render an autocomplete select
class AutocompleteSelectComponent < ViewComponent::Base
  # @includes .................................................................
  include TranslateHelper

  # @security (i.e. attr_accessible) ..........................................
  attr_reader :form, :object, :field, :options, :label, :input, :items

  # @public_instance_methods ..................................................
  # Initialises a Component of Type Button
  #
  # @param form [ActionView::Helpers::FormBuilder] The form builder object (default is nil).
  # @param object [Object] The object associated with the form (default is nil).
  # @param field [Symbol] The field associated with the form (default is nil).
  # @param items [Array] Array of Item Structs.
  # @param options [Hash] Additional options for customizing the autocomplete select.
  #
  # @option options [String] :id The HTML ID attribute for the autocomplete select (default is method input_id).
  # @option options [String] :label The label for the autocomplete select (default is i18n translation).
  # @option options [String] :type The HTML type attribute for the autocomplete select (default is 'select').
  # @option options [Hash] :data Additional data attributes for the autocomplete select.
  #
  # @return [ButtonComponent] A new instance of ButtonComponent.
  #
  def initialize(form:, object:, field:, items:, options: {})
    @form = form
    @object = object
    @field = field
    @options = default_options(options)

    @items = items.map do |item|
      Item.new(id: item[0], label: item[1])
    end
    super
  end

  Item = Struct.new(:id, :label)

  # Sets default options for the autocomplete select.
  #
  # @param options [Hash] Additional options for customizing the autocomplete select.
  #
  # @return [Hash] Merged options with default values.
  #
  def default_options(options)
    {
      id: options[:id] || input_id,
      label: options[:label] || attribute_model(@object, @field),
      type: 'select',
      data: {
        autocomplete_select_target: 'selected',
        action: 'input->autocomplete-select#filterList keydown->autocomplete-select#onKeyDown'
      }
    }
  end

  # @return [String] The HTML ID attribute for the autocomplete select.
  #
  def input_id
    "#{@object.model_name.singular}_#{@field}"
  end
end
