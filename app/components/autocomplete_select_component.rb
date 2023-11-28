# frozen_string_literal: true

# Component to render an autocomplete select
class AutocompleteSelectComponent < ViewComponent::Base
  # @includes .................................................................
  include TranslateHelper

  # @security (i.e. attr_accessible) ..........................................
  attr_reader :form, :object, :field, :options, :label, :input, :items

  # @public_instance_methods ..................................................
  # Initializes a Component of Type Button
  #
  # @param form [ActionView::Helpers::FormBuilder] The form builder object (default is nil).
  # @param link [String] The link possibly associated with the form (default is nil).
  # @param options [Hash] Additional options for customizing the autocomplete select.
  #
  # @option options [String] :id The HTML ID attribute for the autocomplete select (default is method input_id).
  # @option options [String] :label The label for the autocomplete select (default is i18n translation).
  # @option options [String] :colour The colour of the button (default is 'select').
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

  # Set default options for the autocomplete select.
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

  def input_id
    "#{@object.model_name.singular}_#{@field}"
  end
end

# @TODO: Following features:
# - When typing, the first option should be rendered also in the input, but with font-light and grey colour
# - Add option to use a round-colour or an icon or a picure on the far-left
# - Implement through stimulus a possibility to deny an option if already chosen in a previous select (Category, i.e.)
