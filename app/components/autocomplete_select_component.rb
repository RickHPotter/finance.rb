# frozen_string_literal: true

# Component to render an autocomplete select
class AutocompleteSelectComponent < ViewComponent::Base
  include TranslateHelper
  attr_reader :form, :object, :field, :options, :label, :input, :items

  def initialize(form:, object:, field:, items:, options: {})
    @object = object
    @field = field
    @options = default_options(options)

    @items = items.map do |item|
      Item.new(id: item[0], label: item[1])
    end
    super
  end

  private

  Item = Struct.new(:id, :label)

  def default_options(options)
    {
      id: options[:id] || "#{@object.model_name.singular}_#{@field}_select",
      label: options[:label] || attribute_model(@object, @field),
      type: 'select',
      data: {
        autocomplete_select_target: 'selected',
        action: 'input->autocomplete-select#filterList keydown->autocomplete-select#onKeyDown'
      }
    }
  end
end

# TODO: Following features:
# - When typing, the first option should be rendered also in the input, but with font-light and grey colour
# - Add option to use a round-colour or an icon or a picure on the far-left
# - Implement through stimulus a possibility to deny an option if already chosen in a previous select (Category, i.e.)
