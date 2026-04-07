# frozen_string_literal: true

class Views::Shared::SingleSelectCombobox < Views::Base
  include TranslateHelper

  attr_reader :blank_label, :include_blank, :input_data, :name, :options, :placeholder, :selected_value, :term

  def initialize(name:, options:, selected_value:, placeholder:, **attrs)
    @name = name
    @options = options
    @selected_value = selected_value
    @placeholder = placeholder
    @include_blank = attrs.fetch(:include_blank, false)
    @blank_label = attrs.fetch(:blank_label, placeholder)
    @term = attrs.fetch(:term, "items")
    @input_data = attrs.fetch(:input_data, {})
  end

  def view_template
    Combobox(term:, class: "w-full") do
      ComboboxTrigger(placeholder:)

      ComboboxPopover do
        div(class: "my-1") do
          ComboboxSearchInput(placeholder: action_message(:type))
        end

        ComboboxList do
          ComboboxEmptyState { I18n.t(:rows_not_found) }

          if include_blank
            ComboboxItem do
              ComboboxRadio(
                name:,
                value: "",
                id: input_id_for("blank"),
                checked: selected?(nil),
                data: radio_data(blank_label, {})
              )
              span { blank_label }
            end
          end

          options.each do |label, value, option_data|
            ComboboxItem do
              ComboboxRadio(
                name:,
                value:,
                id: input_id_for(value),
                checked: selected?(value),
                data: radio_data(label, option_data || {})
              )
              span { label }
            end
          end
        end
      end
    end
  end

  private

  def input_id_for(value)
    "#{name.to_s.parameterize(separator: '_')}_#{value}"
  end

  def radio_data(label, option_data)
    {
      text: label
    }.merge(input_data).merge(option_data)
  end

  def selected?(value)
    selected_value.to_s == value.to_s
  end
end
