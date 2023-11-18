# frozen_string_literal: true

# Component to render an autocomplete select
class AutocompleteSelectComponent < CustomViewComponent
  include TranslateHelper
  attr_reader :form, :object, :field, :label, :input, :items

  def initialize(form:, object:, field:, items:, options: {})
    @object = object
    @field = field
    @options = default_options(options)

    @items = items.map do |item|
      Item.new(id: item[0], label: item[1])
    end

    set_helpers
    super
  end

  private

  Item = Struct.new(:id, :label)

  def default_options(options)
    {
      id: "#{@object.model_name.singular}_#{@field}_select",
      colour: COLOURS[options[:colour].to_sym ||= 'indigo'],
      label: options[:label] || attribute_model(@object, @field)
    }
  end

  def set_helpers
    if form
      @label = form.label(@field, label_options)
      @input = form.text_field(@field, input_options)
    else
      @label = content_tag(:label, @options[:label], label_options)
      @input = content_tag(:input, nil, input_options)
    end
  end

  def input_options
    {
      id: @id, role: 'combobox', type: 'text', placeholder: ' ',
      class: custom_input_class(colour: @options[:colour]),
      data: {
        autocomplete_select_target: 'selected', placeholder: @options[:placeholder],
        action: 'input->autocomplete-select#filterList keydown->autocomplete-select#onKeyDown'
      }
    }
  end

  def label_options
    {
      for: @id,
      class: custom_label_class(colour: @options[:colour])
    }
  end
end

# TODO: Following features:
# - When typing, the first option should be rendered also in the input, but with font-light and grey colour
# - Bugfix check icon far-right
# - Add option to use a round-colour or an icon or a picure on the far-left
# - Implement through stimulus a possibility to deny an option in a second select if already chosen in a previous select
