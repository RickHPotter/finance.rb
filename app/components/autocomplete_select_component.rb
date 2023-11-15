# frozen_string_literal: true

# Component to render an autocomplete select
class AutocompleteSelectComponent < ViewComponent::Base
  attr_reader :label, :placeholder, :items, :form_name

  def initialize(label:, placeholder:, form_name:, items: [])
    @label = label
    @placeholder = placeholder
    @form_name = form_name
    @items = items
    super
  end

  Item = Struct.new(:id, :label)
end
